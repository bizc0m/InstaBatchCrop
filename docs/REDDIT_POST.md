# Reddit Post Draft

## Title Options

1. I built a native macOS app to batch-crop photos for Instagram without losing the subject
2. InstaBatch Crop: a small macOS tool for batch Instagram cropping with local subject detection
3. I made a SwiftUI macOS app that crops batches of photos to 4:5, 1:1, and 9:16

## Short Post

Hi everyone,

I built a native macOS app called **InstaBatch Crop**.

The goal is simple: drop a folder of images, choose Instagram formats, and export cropped versions in batch while keeping the main subject inside the frame.

It supports:

- portrait 4:5, square 1:1, and story 9:16 exports;
- local macOS Vision analysis for faces, bodies, and visual saliency;
- manual focus points/zones when the automatic crop needs guidance;
- before/after preview;
- direct crop adjustment with mouse, arrows, and zoom;
- JPEG, PNG, and WebP export;
- optional text or transparent image/logo watermark;
- FR/EN interface.

It runs locally on macOS. No cloud processing, no account, no external dependency.

GitHub:
https://github.com/bizc0m/InstaBatchCrop

Direct download:
https://github.com/bizc0m/InstaBatchCrop/releases/download/v2.0/InstaBatch-Crop-V2.0.app.zip

It is currently ad hoc signed, not notarized, so macOS may require right-click > Open on first launch.

I would be interested in feedback from people who edit/export lots of images for Instagram, especially around batch workflow and manual crop correction.

## More Casual Version

I got tired of manually recropping batches of photos for Instagram, so I made a small native macOS app for it.

You drag in photos, pick 4:5 / 1:1 / 9:16, and it exports a batch while trying to keep the important subject in frame. It uses local Vision APIs, and you can add manual focus points or zones when the automatic crop needs help.

There is also preview, mouse-based crop adjustment, JPEG/PNG/WebP export, and optional watermark support.

GitHub:
https://github.com/bizc0m/InstaBatchCrop

Download:
https://github.com/bizc0m/InstaBatchCrop/releases/download/v2.0/InstaBatch-Crop-V2.0.app.zip

Note: it is ad hoc signed, not notarized yet, so first launch may need right-click > Open.
