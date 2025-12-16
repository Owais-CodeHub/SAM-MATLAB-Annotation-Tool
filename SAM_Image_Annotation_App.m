function QuickSAM_Annotation_App()
clc; clear; close all;

% ============================================================
% QuickSAM by Muhammad Owais
% SAM Image-by-Image Annotation (MATLAB GUI)
% - Load ONE image
% - Draw bounding boxes
% - Segment with SAM
% - Refine by adding/removing boxes
% - Save final mask to /Masks and bbox CSV to /BBoxes
% ============================================================

sam = segmentAnythingModel;

% ---------- Theme ----------
BG        = [0.97 0.97 0.98];
CARD_BG   = [1 1 1];
BORDER    = [0.85 0.86 0.88];
HEADER_BG = [0.10 0.12 0.18];
HEADER_TX = [1 1 1];

fig = uifigure("Name","QuickSAM by Muhammad Owais", ...
    "Position",[80 80 1280 740], ...
    "Color", BG);

% ---------- Header ----------
pHeader = uipanel(fig, "Position",[0 690 1280 50], ...
    "BackgroundColor", HEADER_BG, "BorderType","none");

uilabel(pHeader, "Text","QuickSAM by Muhammad Owais", ...
    "Position",[18 10 700 30], "FontSize", 18, ...
    "FontWeight","bold", "FontColor", HEADER_TX);

lblStatus = uilabel(pHeader, "Text","Status: Ready (Load an image to start)", ...
    "Position",[750 13 510 25], "HorizontalAlignment","right", ...
    "FontSize", 12, "FontColor", [0.9 0.93 1]);

% ---------- Cards (Image / Overlay) ----------
cardImg = uipanel(fig, "Title","Image", "FontWeight","bold", ...
    "Position",[20 110 600 565], ...
    "BackgroundColor", CARD_BG, ...
    "HighlightColor", BORDER);

axImg = uiaxes(cardImg, "Position",[18 18 565 510]);
axImg.XTick=[]; axImg.YTick=[]; box(axImg,"on");

cardOut = uipanel(fig, "Title","Mask Overlay", "FontWeight","bold", ...
    "Position",[640 110 600 565], ...
    "BackgroundColor", CARD_BG, ...
    "HighlightColor", BORDER);

axOut = uiaxes(cardOut, "Position",[18 18 565 510]);
axOut.XTick=[]; axOut.YTick=[]; box(axOut,"on");

% ---------- Bottom Controls ----------
ctrl = uipanel(fig, "Title","Controls", "FontWeight","bold", ...
    "Position",[20 15 1220 85], ...
    "BackgroundColor", CARD_BG, ...
    "HighlightColor", BORDER);

btnLoad   = uibutton(ctrl,"Text","📂 Load Image", ...
    "Position",[20 18 170 45], "FontWeight","bold", "ButtonPushedFcn",@onLoad);

btnAddBox = uibutton(ctrl,"Text","➕ Add Box", ...
    "Position",[205 18 140 45], "ButtonPushedFcn",@onAddBox);

btnSeg    = uibutton(ctrl,"Text","🧠 Segment", ...
    "Position",[360 18 140 45], "ButtonPushedFcn",@onSegment);

btnDel    = uibutton(ctrl,"Text","🗑 Delete Last", ...
    "Position",[515 18 160 45], "ButtonPushedFcn",@onDeleteLast);

btnClear  = uibutton(ctrl,"Text","🧹 Clear All", ...
    "Position",[690 18 140 45], "ButtonPushedFcn",@onClearAll);

btnSave   = uibutton(ctrl,"Text","💾 Save Mask + BBox CSV", ...
    "Position",[845 18 220 45], "FontWeight","bold", "ButtonPushedFcn",@onSave);

lblHint = uilabel(ctrl, ...
    "Text","Load → Add boxes → Segment → Save (Masks/ + BBoxes/ created automatically)", ...
    "Position",[1080 10 130 65], "HorizontalAlignment","right", "FontSize", 11);

% Disable actions until image is loaded
setActionEnabled(false);

% -------- State --------
I = [];
emb = [];
imgPath = "";

roiList = gobjects(0);
maskPerROI = {};
finalMask = [];

% ============================================================
% Helpers
% ============================================================

function setStatus(msg)
    lblStatus.Text = "Status: " + msg;
end

function setActionEnabled(tf)
    btnAddBox.Enable = onOff(tf);
    btnSeg.Enable    = onOff(tf);
    btnDel.Enable    = onOff(tf);
    btnClear.Enable  = onOff(tf);
    btnSave.Enable   = onOff(tf);
end

function s = onOff(tf)
    if tf, s="on"; else, s="off"; end
end

function refreshOverlay()
    if isempty(I); return; end
    if isempty(finalMask)
        imshow(I,"Parent",axOut);
        title(axOut,"Mask Overlay","Interpreter","none");
        return;
    end
    overlay = labeloverlay(I, finalMask, "Transparency", 0.55);
    imshow(overlay,"Parent",axOut);
    title(axOut, sprintf("Mask Overlay (Objects: %d)", numel(maskPerROI)), "Interpreter","none");
end

function recomputeFinalMask()
    if isempty(I)
        finalMask = [];
        return;
    end
    m = false(size(I,1), size(I,2));
    for k = 1:numel(maskPerROI)
        if ~isempty(maskPerROI{k})
            m = m | maskPerROI{k};
        end
    end
    finalMask = m;
end

function safeDeleteROIs()
    if ~isempty(roiList)
        delete(roiList(ishandle(roiList)));
    end
    roiList = gobjects(0);
end

% ============================================================
% Callbacks
% ============================================================

function onLoad(~,~)
    [file,path] = uigetfile({'*.jpg;*.jpeg;*.png;*.bmp;*.tif;*.tiff'}, 'Select image');
    if isequal(file,0); return; end

    imgPath = fullfile(path,file);
    I = imread(imgPath);

    safeDeleteROIs();
    maskPerROI = {};
    finalMask = [];

    imshow(I,"Parent",axImg);
    title(axImg, "Image: " + string(file), "Interpreter","none");

    % Precompute embeddings once per image
    emb = extractEmbeddings(sam, I);

    refreshOverlay();
    setActionEnabled(true);
    setStatus("Image loaded. Add one or more boxes, then click Segment.");
end

function onAddBox(~,~)
    if isempty(I)
        setStatus("Load an image first.");
        return;
    end

    roi = drawrectangle(axImg, "Color",[0 0.7 1], "LineWidth",2);
    roiList(end+1) = roi;
    maskPerROI{end+1} = [];

    setStatus(sprintf("Box added (%d). Click Segment.", numel(roiList)));
end

function onSegment(~,~)
    if isempty(I) || isempty(roiList)
        setStatus("Draw at least one box first.");
        return;
    end

    validIdx = find(isvalid(roiList));
    if isempty(validIdx)
        setStatus("No valid boxes found. Add a new box.");
        return;
    end

    if numel(maskPerROI) < numel(roiList)
        maskPerROI(numel(maskPerROI)+1:numel(roiList)) = {[]};
    end

    for ii = 1:numel(validIdx)
        k = validIdx(ii);
        box = roiList(k).Position;  % [x y w h]

        mask = segmentObjectsFromEmbeddings(sam, emb, size(I), BoundingBox=box);

        if isempty(mask)
            maskPerROI{k} = [];
        else
            maskPerROI{k} = logical(mask);
        end
    end

    recomputeFinalMask();
    refreshOverlay();
    setStatus("Segmentation updated. Save when ready.");
end

function onDeleteLast(~,~)
    if isempty(roiList)
        setStatus("No boxes to delete.");
        return;
    end

    k = numel(roiList);
    while k >= 1 && ~isvalid(roiList(k))
        k = k - 1;
    end
    if k < 1
        setStatus("No valid boxes to delete.");
        return;
    end

    delete(roiList(k));
    roiList(k) = [];
    maskPerROI(k) = [];

    recomputeFinalMask();
    refreshOverlay();
    setStatus(sprintf("Deleted last box. Remaining boxes: %d", numel(roiList)));
end

function onClearAll(~,~)
    safeDeleteROIs();
    maskPerROI = {};
    finalMask = [];
    refreshOverlay();
    setStatus("Cleared all boxes and masks.");
end

function onSave(~,~)
    if isempty(finalMask)
        setStatus("Nothing to save. Click Segment first.");
        return;
    end
    if isempty(imgPath)
        setStatus("No image loaded.");
        return;
    end

    [imgDir, base, ~] = fileparts(imgPath);

    % ---- 1) Save MASK ----
    maskDir = fullfile(imgDir, "Masks");
    if ~exist(maskDir,"dir"); mkdir(maskDir); end
    maskPath = fullfile(maskDir, base + "_mask.png");
    imwrite(uint8(finalMask)*255, maskPath);

    % ---- 2) Save BBOX CSV ----
    bboxDir = fullfile(imgDir, "BBoxes");
    if ~exist(bboxDir,"dir"); mkdir(bboxDir); end
    csvPath = fullfile(bboxDir, base + "_bboxes.csv");

    validIdx = find(isvalid(roiList));
    if isempty(validIdx)
        T = table([],[],[],[],[],[],[],[], ...
            'VariableNames',{'x','y','w','h','x1','y1','x2','y2'});
        writetable(T, csvPath);
        setStatus("Saved mask. No boxes found (empty CSV written).");
        return;
    end

    boxes = zeros(numel(validIdx),4);
    for ii = 1:numel(validIdx)
        k = validIdx(ii);
        boxes(ii,:) = roiList(k).Position; % [x y w h]
    end

    x  = boxes(:,1); y  = boxes(:,2); w = boxes(:,3); h = boxes(:,4);
    x1 = x; y1 = y;
    x2 = x + w; y2 = y + h;

    T = table(x,y,w,h,x1,y1,x2,y2, ...
        'VariableNames',{'x','y','w','h','x1','y1','x2','y2'});
    writetable(T, csvPath);

    setStatus("Saved: " + string(maskPath) + " | " + string(csvPath));
end

end
