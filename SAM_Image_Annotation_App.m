function SAM_Image_Annotation_App()
clc;clear; close all;

    sam = segmentAnythingModel;

    fig = uifigure("Name","SAM Image Annotation","Position",[100 100 1200 700]);

    axImg = uiaxes(fig, "Position",[20 80 560 600]);
    axImg.XTick = []; axImg.YTick = [];
    title(axImg, "Image");

    axOut = uiaxes(fig, "Position",[620 80 560 600]);
    axOut.XTick = []; axOut.YTick = [];
    title(axOut, "Mask Overlay");

    lbl = uilabel(fig, "Position",[20 20 560 40], ...
        "Text","Load an image → Add boxes → Segment → Save Mask");

    btnLoad   = uibutton(fig,"Text","📂 Load Image","Position",[860 20 110 40],"ButtonPushedFcn",@onLoad);
    btnAddBox = uibutton(fig,"Text","➕ Add Box","Position",[980 20 90 40],"ButtonPushedFcn",@onAddBox);
    btnSeg    = uibutton(fig,"Text","🧠 Segment","Position",[1080 20 90 40],"ButtonPushedFcn",@onSegment);

    btnDel    = uibutton(fig,"Text","🗑 Delete Last Box","Position",[620 20 150 40],"ButtonPushedFcn",@onDeleteLast);
    btnClear  = uibutton(fig,"Text","🧹 Clear All","Position",[780 20 80 40],"ButtonPushedFcn",@onClearAll);
    btnSave   = uibutton(fig,"Text","💾 Save Mask + BBox CSV","Position",[20 20 170 40],"ButtonPushedFcn",@onSave);

    % -------- State --------
    I = [];
    emb = [];
    imgPath = "";

    roiList = gobjects(0);
    maskPerROI = {};
    finalMask = [];

    % =========================
    % Helpers
    % =========================
    function refreshOverlay()
        if isempty(I); return; end
        if isempty(finalMask)
            imshow(I,"Parent",axOut); title(axOut,"Mask Overlay"); return;
        end
        overlay = labeloverlay(I, finalMask, "Transparency", 0.55);
        imshow(overlay,"Parent",axOut);
        title(axOut, sprintf("Mask Overlay (Objects: %d)", numel(maskPerROI)));
    end

    function recomputeFinalMask()
        if isempty(I); finalMask = []; return; end
        m = false(size(I,1), size(I,2));
        for k = 1:numel(maskPerROI)
            if ~isempty(maskPerROI{k})
                m = m | maskPerROI{k};
            end
        end
        finalMask = m;
    end

    % =========================
    % Callbacks
    % =========================
    function onLoad(~,~)
        [file,path] = uigetfile({'*.jpg;*.png;*.bmp;*.tif;*.tiff'}, 'Select image');
        if isequal(file,0); return; end

        imgPath = fullfile(path,file);
        I = imread(imgPath);

        delete(roiList(ishandle(roiList)));
        roiList = gobjects(0);
        maskPerROI = {};
        finalMask = [];

        imshow(I,"Parent",axImg);
        title(axImg,file);

        emb = extractEmbeddings(sam,I);

        refreshOverlay();
        lbl.Text = "Draw boxes on LEFT → Click Segment → Save Mask + BBox CSV.";
    end

    function onAddBox(~,~)
        if isempty(I)
            lbl.Text = "Load an image first.";
            return;
        end
        roi = drawrectangle(axImg,"Color",[0 0.7 1],"LineWidth",2);
        roiList(end+1) = roi;
        maskPerROI{end+1} = [];
        lbl.Text = sprintf("Box added (%d). Click Segment.", numel(roiList));
    end

    function onSegment(~,~)
        if isempty(I) || isempty(roiList)
            lbl.Text = "Draw at least one box first.";
            return;
        end

        validIdx = find(isvalid(roiList));
        if isempty(validIdx)
            lbl.Text = "No valid boxes found. Add a new box.";
            return;
        end

        if numel(maskPerROI) < numel(roiList)
            maskPerROI(numel(maskPerROI)+1:numel(roiList)) = {[]};
        end

        for ii = 1:numel(validIdx)
            k = validIdx(ii);
            box = roiList(k).Position;  % [x y w h]

            mask = segmentObjectsFromEmbeddings( ...
                sam, emb, size(I), BoundingBox=box);

            if isempty(mask)
                maskPerROI{k} = [];
            else
                maskPerROI{k} = logical(mask);
            end
        end

        recomputeFinalMask();
        refreshOverlay();
        lbl.Text = "Segmentation updated. Save when ready.";
    end

    function onDeleteLast(~,~)
        if isempty(roiList)
            lbl.Text = "No boxes to delete.";
            return;
        end
        k = numel(roiList);
        while k >= 1 && ~isvalid(roiList(k))
            k = k - 1;
        end
        if k < 1
            lbl.Text = "No valid boxes to delete.";
            return;
        end

        delete(roiList(k));
        roiList(k) = [];
        maskPerROI(k) = [];

        recomputeFinalMask();
        refreshOverlay();
        lbl.Text = sprintf("Deleted last box. Remaining boxes: %d", numel(roiList));
    end

    function onClearAll(~,~)
        if ~isempty(roiList)
            delete(roiList(ishandle(roiList)));
        end
        roiList = gobjects(0);
        maskPerROI = {};
        finalMask = [];
        refreshOverlay();
        lbl.Text = "Cleared all boxes and masks.";
    end

    function onSave(~,~)
        if isempty(finalMask)
            lbl.Text = "Nothing to save. Click Segment first.";
            return;
        end
        if isempty(imgPath)
            lbl.Text = "No image loaded.";
            return;
        end

        [imgDir,base,~] = fileparts(imgPath);

        % ---- 1) Save MASK ----
        maskDir = fullfile(imgDir,"Masks");
        if ~exist(maskDir,"dir"); mkdir(maskDir); end
        maskPath = fullfile(maskDir, base + "_mask.png");
        imwrite(uint8(finalMask)*255, maskPath);

        % ---- 2) Save BBOX CSV ----
        bboxDir = fullfile(imgDir,"BBoxes");
        if ~exist(bboxDir,"dir"); mkdir(bboxDir); end
        csvPath = fullfile(bboxDir, base + "_bboxes.csv");

        % Collect valid boxes
        validIdx = find(isvalid(roiList));
        if isempty(validIdx)
            % still save an empty CSV with header
            T = table([],[],[],[],[],[], ...
                'VariableNames',{'x','y','w','h','x1','y1'});
            writetable(T, csvPath);
            lbl.Text = "Saved mask. No boxes to save (empty CSV written).";
            return;
        end

        boxes = zeros(numel(validIdx),4);
        for ii = 1:numel(validIdx)
            k = validIdx(ii);
            boxes(ii,:) = roiList(k).Position; % [x y w h]
        end

        % Optional derived corners
        x  = boxes(:,1); y  = boxes(:,2); w = boxes(:,3); h = boxes(:,4);
        x1 = x; y1 = y;
        x2 = x + w; y2 = y + h;

        T = table(x,y,w,h,x1,y1,x2,y2, ...
            'VariableNames',{'x','y','w','h','x1','y1','x2','y2'});

        writetable(T, csvPath);

        lbl.Text = "Saved: " + maskPath + "  |  " + csvPath;
    end
end
