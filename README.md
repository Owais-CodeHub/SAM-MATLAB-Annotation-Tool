# 🧠 SAM-MATLAB-Annotation-Tool  
### Interactive Image Annotation Using Segment Anything Model (SAM) in MATLAB

<p align="center">
  <img src="README Data/Screenshot 1.jpg" alt="SAM MATLAB Annotation Tool Screenshot" width="90%">
</p>

<p align="center">
  <b>A training-free image annotation tool built in MATLAB using the Segment Anything Model (SAM)</b>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/MATLAB-R2024a+-orange">
  <img src="https://img.shields.io/badge/Segment%20Anything-SAM-blue">
  <img src="https://img.shields.io/badge/Annotation-Interactive-success">
  <img src="https://img.shields.io/badge/License-MIT-lightgrey">
</p>

---

## 🔍 Overview

**SAM-MATLAB-Annotation-Tool** is a clean, interactive, and production-ready image annotation application developed entirely in **MATLAB** and powered by the **Segment Anything Model (SAM)**.

The tool enables **image-by-image annotation** using **bounding boxes (and extensible point prompts)**, producing **high-quality segmentation masks** without any model training.  
It is ideal for **researchers, engineers, and practitioners** who want fast and accurate ground-truth generation directly inside MATLAB.

---

## ✨ Key Capabilities

✔ Interactive **bounding-box based segmentation**  
✔ Powered by **foundation model (SAM)** — no fine-tuning required  
✔ **Iterative refinement** (add / delete boxes at any time)  
✔ Clean MATLAB **GUI-based workflow**  
✔ Automatic export of:
- 🖼 Segmentation masks (`.png`)
- 📦 Bounding boxes (`.csv`)  
✔ Auto-generated dataset structure (`Masks/`, `BBoxes/`)  
✔ Ready for **deep learning pipelines** (YOLO / COCO compatible)

---

## 🖼 User Interface

The interface is designed to be **simple, intuitive, and professional**:

- **Left panel**: Image annotation (draw bounding boxes)
- **Right panel**: Real-time segmentation overlay
- **Bottom controls**:
  - Load Image
  - Add / Delete Boxes
  - Segment
  - Save Mask + BBox

> The screenshot above shows a real annotation session using SAM inside MATLAB.

---

## 🧠 Annotation Outputs

For each annotated image, the tool automatically generates:

### 1️⃣ Original Image and Segmentation Mask
a) Image 1.jpg

<p align="center">
  <img src="README Data/Picture1.png" alt="SAM MATLAB Annotation Tool Screenshot" width="40%">
</p>


- Binary mask
- Foreground = 255, Background = 0

### 2️⃣ Bounding Box Annotations

BBoxes/Image 1_bboxes.csv


**CSV format**
| Column | Description |
|------|-------------|
| x, y | Top-left corner |
| w, h | Width & height |
| x1, y1 | Top-left (corner format) |
| x2, y2 | Bottom-right |

This format is **directly convertible** to YOLO, COCO, or custom pipelines.

---

## 🛠 System Requirements

### MATLAB
- **MATLAB R2024a or newer** (recommended)

### Required Toolboxes
- Image Processing Toolbox
- Deep Learning Toolbox
- Image Processing Toolbox Model for Segment Anything Model (Support Package)

> GPU is optional. CPU-only execution is fully supported.

---

## 🚀 Getting Started

### Clone the Repository
```bash

git clone 
https://github.com/Owais-CodeHub/SAM-MATLAB-Annotation-Tool.git


Open MATLAB

Ensure all required toolboxes and the SAM support package are installed.

Run the Application

SAM_Image_Annotation_App.m
