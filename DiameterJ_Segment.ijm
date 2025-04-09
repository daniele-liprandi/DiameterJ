// Macro to perform and compare image segmentation methods in ImageJ/FIJI
// Refactored for clarity, maintainability, and correctness.
// Uses global variables for dialog settings due to Dialog.show issue.

// --- Global Variable Declarations ---
// These will be set by getUserInput and used by runMacro and others
var image_width_default;
var image_height_default;
var crop_outcome;
var crop_tlx;
var crop_tly;
var crop_brx;
var crop_bry;
var TLCB_None; // Top-Left CheckBox (None)
var TRCB_Trad; // Top-Right CheckBox (Traditional)
var BLCB_SRM;  // Bottom-Left CheckBox (SRM)
var BRCB_Mix;  // Bottom-Right CheckBox (Mixed)
var Batch_analysis;
var thresh_dots;
var dirOutputBase; // Directory for saving results

// --- Configuration Variables (Effectively Global) ---
var POST_PROCESS_OUTLIER_RADIUS = 3;
var POST_PROCESS_OUTLIER_THRESHOLD = 50;
var SRM_Q_VALUE_1 = 25;
var SRM_Q_VALUE_2 = 12;
var SRM_Q_VALUE_3 = 10;
var MONTAGE_SCALE = 0.75;
var MONTAGE_BORDER = 5;
var MONTAGE_FONT_SIZE_SMALL = 18;
var MONTAGE_FONT_SIZE_MEDIUM = 27;
var MONTAGE_FONT_SIZE_LARGE = 39;
var MONTAGE_LABEL_COLOR_R = 175;
var MONTAGE_LABEL_COLOR_G = 0;
var MONTAGE_LABEL_COLOR_B = 0;
var DEFAULT_IMAGE_WIDTH = 1280;
var DEFAULT_IMAGE_HEIGHT = 960;

// --- Main Execution ---
runMacro();

// ==========================================================
// Main Function Orchestrating the Process
// ==========================================================
function runMacro() {
	print("DEBUG: Starting runMacro...");

	// --- Get User Input ---
	print("DEBUG: Calling getUserInput...");
	var inputSuccessful = getUserInput(); // Call function to set globals
	print("DEBUG: getUserInput returned: " + inputSuccessful);

	if (!inputSuccessful) { // Check return value (still useful if errors occur in getUserInput)
		print("User cancelled Dialog or input failed.");
		return; // Exit
	}
	// Proceed using the globally set variables (Batch_analysis, etc.)
	print("DEBUG: Assuming User Input was successful, proceeding...");

	// --- Check ImageJ/FIJI Version for Threshold command ---
	var IJorFIJI = getVersion(); // IJorFIJI is local to runMacro
	if (startsWith(IJorFIJI, "1.")) {
		thresh_dots = "Auto Threshold..."; // Set global thresh_dots
	} else {
		thresh_dots = "Auto Threshold"; // Set global thresh_dots
	}
	print("Using threshold command: " + thresh_dots);

	// --- Timing ---
	var T1 = getTime(); // T1 is local

	// --- Processing Logic ---
	if (Batch_analysis == "Yes") { // Access global Batch_analysis
		// Batch Processing
		var dirSource = getDirectory("Choose Source Directory "); // dirSource is local
		if (dirSource == "null") return; // User cancelled
		var list = getFileList(dirSource); // list is local
		if (list.length == 0) {
			print("No files found in source directory: " + dirSource);
			return;
		}
		dirOutputBase = dirSource; // Set the global dirOutputBase
		print("DEBUG: Set global dirOutputBase (Batch): " + dirOutputBase);
		setBatchMode(true); // Keep batch mode active

		for (var i = 0; i < list.length; i++) {
			showProgress(i + 1, list.length);
			var filename = dirSource + list[i];
			var lowerCaseFilename = toLowerCase(filename);


			if (endsWith(lowerCaseFilename, ".tif") || endsWith(lowerCaseFilename, ".tiff") ||
				endsWith(lowerCaseFilename, ".jpg") || endsWith(lowerCaseFilename, ".jpeg") ||
				endsWith(lowerCaseFilename, ".gif") || endsWith(lowerCaseFilename, ".bmp") ||
				endsWith(lowerCaseFilename, ".png"))
			{
				print("--------------------");
				print("Analyzing image: " + list[i]);
				var imgID = openImageAndGetID(filename); // Open image, get ID

                if (imgID == 0) { // Check for actual failure (0 is invalid ID)
                    print("  ERROR: Skipping processing as a valid Image ID was not obtained for " + list[i]);
                    // Ensure no stray windows are left if open failed partially
                    var expectedTitle = getTitleFromPath(filename);
                    if(isOpen(expectedTitle)) { // Use isOpen(title) here
                        selectWindow(expectedTitle); close();
                    }
                    continue; // Skip to the next file
                }

                // --- If we get here, imgID should be valid (negative) ---
                print("  DEBUG: Image " + list[i] + " opened with valid ID: " + imgID);

				// --- FORCE SELECTION using the obtained ID ---
				print("  DEBUG: Attempting to select image with ID: " + imgID);
				selectImage(imgID);
				wait(50); // Tiny pause after selecting

                // --- Verify selection (optional but good) ---
                var activeID = getImageID();
                var activeTitle = getTitle();
                if (activeID != imgID) {
                     print("  ERROR: Failed to select image ID " + imgID + "! Active ID is " + activeID + " ('" + activeTitle + "'). Skipping processing.");
                     // Decide whether to close the wrongly focused window? Or the target window?
                     if (isOpen(imgID)) closeImage(imgID); // Try closing target ID
                     continue; // Skip to next file
                }
                print("  DEBUG: Image ID " + imgID + " ('"+activeTitle+"') successfully selected.");

                // --- Call processing function ---
				var outputPaths = processSingleImage(imgID);

                // --- Check result from processing ---
				if (outputPaths == "") { // Check for "" failure indicator
				    print("  INFO: Processing function failed or returned no paths for " + list[i] + ". Skipping montage creation.");
                } else if (outputPaths != "") {
				    // --- Create Montages ---
                    print("  DEBUG: Calling createMontagesIfNeeded for " + list[i]);
					createMontagesIfNeeded(outputPaths, imgID);
				}

				// --- IMPORTANT: Close the image *ONLY HERE* after all processing for it is done ---
                // Make sure no other closeImage(imgID) exists elsewhere in this loop structure

				print("Finished processing: " + list[i]);

			} // End extension check
		}
		setBatchMode(false);
		showProgress(1.0);

	} else {
		// Single Image Processing
		print("DEBUG: Entering Single Image Processing mode...");
		if (nImages() == 0) { // Explicitly check if any images are open
			print("ERROR: No images are open. Please open an image before running in single mode.");
			return;
		}
		imgID = getImageID(); // Use getImageID() which gets the ID of the active image
        imgTitle = getTitle(); // Get the title while it's active

        print("DEBUG: Active Image Title: '" + imgTitle + "', ID: " + imgID);

		dirOutputBase = getDirectory("Choose Directory to Store Output Images In"); // Set global dirOutputBase
		if (dirOutputBase == "null") { print("DEBUG: User cancelled directory selection."); return; }
        print("DEBUG: Set global dirOutputBase (Single): " + dirOutputBase);

		print("--------------------");
		print("Analyzing image: " + imgTitle); // Use the stored title
		setBatchMode(true); // Optional

        // Ensure the correct image is selected before processing
        selectImage(imgID);
        if(getImageID() != imgID) { // Double check selection worked
             print("ERROR: Failed to select image ID " + imgID + " for processing.");
             setBatchMode(false);
             return;
        }
        print("DEBUG: Image ID " + imgID + " selected for processing.");

		var outputPaths = processSingleImage(imgID); // outputPaths is local
        print("DEBUG: processSingleImage returned paths: " + outputPaths);

		if (outputPaths == "null" && outputPaths != "") {
            print("DEBUG: Calling createMontagesIfNeeded...");
			createMontagesIfNeeded(outputPaths, imgID);
		} else {
            print("DEBUG: Skipping createMontagesIfNeeded as outputPaths are null or empty.");
        }
		// Don't close the original image in single mode

        // Re-select the original image window at the end for user convenience
        if (isOpen(imgID)) { // Check if it's still open
             selectImage(imgID);
        }

		//setBatchMode(false);
		print("Finished processing: " + imgTitle); // Use stored title
	}

	// --- Final Report ---
	var T2 = getTime(); // T2 is local
	var TTime = (T2 - T1) / 1000; // TTime is local
	setForegroundColor(0, 0, 0);
	print("====================");
	if (TLCB_None == 1) { // Access global TLCB_None
		print("Image Cropping Completed in: " + TTime + " Seconds");
	} else {
        // Check if any segmentation was actually selected and run
        if (TRCB_Trad==1 || BLCB_SRM==1 || BRCB_Mix==1) {
		    print("Image Segmentation Completed in: " + TTime + " Seconds");
        } else {
            print("No segmentation performed (only cropping might have occurred if selected).");
        }
	}
    if(dirOutputBase == "null" && dirOutputBase != "") print("Outputs saved in: " + dirOutputBase); // Access global
	print("====================");
	//if(isOpen("Log")) selectWindow("Log");
    print("DEBUG: runMacro finished.");
	run("Close All"); // Close all images at the end of the macro
}


// ==========================================================
// User Input Dialog Function (Fragile Workaround - Assume OK, No Try/Catch)
// ==========================================================
function getUserInput() {
    print("DEBUG: Entering getUserInput (Fragile Workaround - Assuming OK)...");
	// This workaround ASSUMES the user pressed OK because Dialog.show returns 0.

	Dialog.create("Segmentation Setup");

	// --- Dialog Definition ---
	Dialog.setInsets(0, 80, 0);
	Dialog.addMessage("Basic Image Information (Defaults)");
	Dialog.addNumber("Default Image Width", DEFAULT_IMAGE_WIDTH, 0, 7, "Pixels");
	Dialog.addNumber("Default Image Height", DEFAULT_IMAGE_HEIGHT, 0, 7, "Pixels");
	Dialog.setInsets(25, 98, 0);
	Dialog.addMessage("Cropping Location");
	var crop_items = newArray("Yes", "No"); // Local array
	Dialog.addChoice("Crop image(s)?", crop_items, "Yes");
	Dialog.addNumber("Crop Top Left - X", 0);
	Dialog.addNumber("Crop Top Left - Y", 0);
	Dialog.addNumber("Crop Bottom Right - X", DEFAULT_IMAGE_WIDTH);
	Dialog.addNumber("Crop Bottom Right - Y", DEFAULT_IMAGE_HEIGHT - 80);
	Dialog.setInsets(25, 58, 0);
	Dialog.addMessage("Segmentation Algorithms to Use");
	var Seg_labels = newArray("None (Crop Only)", "Traditional", "Stat. Region Merged", "Mixed"); // Local array
	var Seg_defaults = newArray(false, false, true, true); // Local array
	Dialog.addCheckboxGroup(2, 2, Seg_labels, Seg_defaults);
	Dialog.setInsets(25, 98, 0);
	Dialog.addMessage("Batch Processing");
	var radio_items = newArray("Yes", "No"); // Local array
	Dialog.addRadioButtonGroup("Analyze multiple images from a directory?", radio_items, 1, 2, "Yes");
	// --- End Dialog Definition ---

    print("DEBUG: About to call Dialog.show (ignoring return value)...");
	Dialog.show; // Call show, assume OK unless macro halts.
    print("DEBUG: Dialog.show executed. Proceeding as if OK was pressed.");

    // Retrieve values, assigning directly to GLOBAL variables (no 'var')
    // No try/catch block here
    print("DEBUG: Retrieving dialog values...");
    image_width_default = Dialog.getNumber(); // Assign to global
    image_height_default = Dialog.getNumber();// Assign to global
    crop_outcome = Dialog.getChoice();        // Assign to global
    // Get crop numbers regardless of choice, assign to temporary local vars first
    var crop_tlx_temp = Dialog.getNumber(); // Local temp
    var crop_tly_temp = Dialog.getNumber(); // Local temp
    var crop_brx_temp = Dialog.getNumber(); // Local temp
    var crop_bry_temp = Dialog.getNumber(); // Local temp
    // Get checkboxes
    TLCB_None = Dialog.getCheckbox();     // Assign to global
    TRCB_Trad = Dialog.getCheckbox();     // Assign to global
    BLCB_SRM = Dialog.getCheckbox();      // Assign to global
    BRCB_Mix = Dialog.getCheckbox();      // Assign to global
    // Get radio button
    Batch_analysis = Dialog.getRadioButton(); // Assign to global
    print("DEBUG: Retrieved all dialog values (assuming OK).");

    // Handle crop_outcome *after* retrieving all values
    if (crop_outcome == "No") {
        print("DEBUG: Crop outcome is No. Setting global crop coords based on retrieved defaults.");
        crop_tlx = 0; // Assign to global
        crop_tly = 0; // Assign to global
        crop_brx = image_width_default; // Use global default
        crop_bry = image_height_default; // Use global default
    } else {
        print("DEBUG: Crop outcome is Yes. Setting global crop coords from retrieved temps.");
        crop_tlx = crop_tlx_temp; // Assign to global
        crop_tly = crop_tly_temp; // Assign to global
        crop_brx = crop_brx_temp; // Assign to global
        crop_bry = crop_bry_temp; // Assign to global
        // Validate crop coords if Yes was selected
        print("DEBUG: Performing input validation...");
        if (crop_brx <= crop_tlx || crop_bry <= crop_tly) {
            exit("Invalid crop coordinates: Bottom Right must be greater than Top Left.");
        }
        print("DEBUG: Input validation passed.");
    }

	print("DEBUG: getUserInput finished successfully (assuming OK). Returning true.");
	return true; // Assume success if we got here
}

// ==========================================================
// Core Image Processing Function (for a single image)
// ==========================================================
function processSingleImage(imgID) { // Takes the initial imgID
    // Accesses globals: dirOutputBase, crop_outcome, crop_tlx, etc., TLCB_None, etc.
    // Accesses global segmentation flags (TRCB_Trad, BLCB_SRM, BRCB_Mix)
    // Accesses global baseName construction logic (implicitly via segmentation funcs)
    // Accesses global segmentation settings (SRM_Q_VALUE_*, POST_PROCESS_*) via called funcs
    // Accesses global thresh_dots via called funcs

    print("  DEBUG: Entering processSingleImage for initial ID: " + imgID);
	print("  DEBUG: Image ID to process: " + imgID + ", Title: " + getTitle()); // Get title for logging
	selectImage(imgID); // Make sure the correct image is active initially
	var originalTitle = getTitle(); // Store original title
	var baseName = removeExtension(originalTitle); // For creating output names
	var paths = ""; // Local variable for accumulating output paths string
    var currentImgID = imgID; // Start with the initial ID

	// --- Create Output Directories (using global dirOutputBase) ---
    if (dirOutputBase == "" || dirOutputBase == "null") {
        print("ERROR: Output directory (dirOutputBase) not set in processSingleImage.");
        return "";
    }
	var dirBestSeg = dirOutputBase + "Best Segmentation" + File.separator; // Local path vars
	var dirSegmented = dirOutputBase + "Segmented Images" + File.separator;
	var dirMontage = dirOutputBase + "Montage Images" + File.separator;
	File.makeDirectory(dirBestSeg);
	File.makeDirectory(dirSegmented);
	File.makeDirectory(dirMontage);
	if (!File.exists(dirBestSeg) || !File.exists(dirSegmented) || !File.exists(dirMontage)) {
		print("Error: Unable to create output directories in " + dirOutputBase);
		return "";
	}
    print("  DEBUG: Output directories ensured/created in: " + dirOutputBase);

	// --- Set Scale (Pixels) ---
	run("Set Scale...", "distance=0 known=0 pixel=1 unit=pixels");

    // --- Handle Cropping (using global crop variables) ---
    var width = getWidth(); // Local vars for dimensions
    var height = getHeight();
    print("  DEBUG: Initial dimensions: " + width + "x" + height);
    var didCrop = false; // Local flag to track if cropping occurred

    if (crop_outcome == "Yes") { // Access global crop_outcome
		print("  DEBUG: Crop outcome is Yes. Calculating crop rectangle...");
		// Use globally set crop_tlx, crop_tly, crop_brx, crop_bry

        // Adjust coordinates if they exceed current image bounds
        var actual_crop_tlx; // Declare local vars for adjusted coords
        var actual_crop_tly;
        var actual_crop_brx;
        var actual_crop_bry;

        if (crop_tlx < 0) actual_crop_tlx = 0; else actual_crop_tlx = crop_tlx;
        if (crop_tly < 0) actual_crop_tly = 0; else actual_crop_tly = crop_tly;
        if (crop_brx > width) actual_crop_brx = width; else actual_crop_brx = crop_brx;
        if (crop_bry > height) actual_crop_bry = height; else actual_crop_bry = crop_bry;

        var cropWidth = actual_crop_brx - actual_crop_tlx; // Local calculation vars
        var cropHeight = actual_crop_bry - actual_crop_tly;
        print("  DEBUG: Calculated effective crop coords: x=" + actual_crop_tlx + ", y=" + actual_crop_tly + ", w=" + cropWidth + ", h=" + cropHeight);

		if (cropWidth <= 0 || cropHeight <= 0) {
			print("  WARNING: Invalid effective crop dimensions calculated for " + originalTitle + " ["+cropWidth+"x"+cropHeight+"]. Using full image instead.");
			currentImgID = imgID;
			didCrop = false; // Mark as not cropped
		} else {
			print("  Cropping " + originalTitle + " to: [" + actual_crop_tlx + "," + actual_crop_tly + "," + cropWidth + "," + cropHeight + "]");
			makeRectangle(actual_crop_tlx, actual_crop_tly, cropWidth, cropHeight);
        	run("Crop"); // This closes the original window and opens a new one
            didCrop = true;
            wait(300); // <<<=== PAUSE AFTER CROP ===>>> Allow window registration

            // --- Get ID of the NEW window ---
            currentImgID = 0; // Reset ID
            var titleAfterCrop = originalTitle; // Assume title is the same initially

            if (isOpen(titleAfterCrop)) { // Use isOpen(title)
                 print("  DEBUG: Selecting cropped window by original title '" + titleAfterCrop + "'...");
                 selectWindow(titleAfterCrop);
                 wait(100);
                 currentImgID = getImageID();
                 if (currentImgID != 0) {
                      print("  DEBUG: Selected by title. ID of cropped window: " + currentImgID);
                 } else {
                      print("  ERROR: Selected cropped window by title, but failed to get valid ID!");
                 }
            } else {
                 print("  ERROR: Cropped window '" + titleAfterCrop + "' not found by title!");
                 // Could check for title + "-1" if needed, but less likely after crop
            }

            if (currentImgID == 0) {
                 print("  ERROR: Failed to get valid ID for cropped window. Cannot proceed.");
                 return ""; // Indicate failure
            }
            // --- End Get ID of NEW window ---

            // Update width/height variables
            width = getWidth();
            height = getHeight();
            print("  DEBUG: Dimensions after crop: " + width + "x" + height);
		}
    } else {
        // No cropping selected
		print("  DEBUG: Using full image (no cropping) for " + originalTitle);
        // currentImgID remains the initial imgID passed into the function
        print("  DEBUG: No cropping, using original Image ID: " + currentImgID);
    }

	print("  DEBUG: Image ID to be processed: " + currentImgID);
	selectImage(currentImgID);
	if(getImageID()!=currentImgID){ print("ERROR: Failed selection before seg!"); return "";}
	print("  DEBUG: Correct image selected (ID " + currentImgID + ").");


	// --- Handle "None" Option (using global TLCB_None) ---
	if (TLCB_None == 1) {
        print("  DEBUG: 'None' option selected. Saving image and exiting processSingleImage.");
		var pathNone = dirBestSeg + baseName + "_CroppedOrOriginal.tif"; // Local var
		saveImage(currentImgID, pathNone); // Save the current image (cropped or original)
		print("  Saved image to: " + pathNone);
		paths = "ORIGINAL:" + pathNone; // Set path for potential montage later
        if (didCrop) { // If we created a new cropped window, close it
             print("  DEBUG: Closing cropped image window (ID: " + currentImgID + ")");
             closeImage(currentImgID);
        }
		return paths; // Return only this path
	}

	// --- Run Selected Segmentation Algorithms (using currentImgID) ---
    // The called functions use global flags TRCB_Trad, BLCB_SRM, BRCB_Mix to run
	var traditionalPaths = ""; // Local vars
	var srmPaths = "";
	var mixedPaths = "";

	if (TRCB_Trad == 1) {
        print("  DEBUG: Calling runTraditionalSegmentation for ID: " + currentImgID);
		traditionalPaths = runTraditionalSegmentation(currentImgID, dirSegmented, baseName);
		paths += traditionalPaths;
	}
	if (BLCB_SRM == 1) {
        print("  DEBUG: Calling runSrmSegmentation for ID: " + currentImgID);
		srmPaths = runSrmSegmentation(currentImgID, dirSegmented, baseName);
		if (paths != "") paths += "|";
		paths += srmPaths;
	}
	if (BRCB_Mix == 1) {
        print("  DEBUG: Calling runMixedSegmentation for ID: " + currentImgID);
		mixedPaths = runMixedSegmentation(currentImgID, dirSegmented, baseName);
		if (paths != "") paths += "|";
		paths += mixedPaths;
	}


	// --- Save copy of (cropped or original) image for montage (using currentImgID) ---
	var pathOriginal = dirSegmented + baseName + "_OriginalForMontage.tif"; // Local var
    print("  DEBUG: Saving copy for montage from ID " + currentImgID + " to " + pathOriginal);
	saveImage(currentImgID, pathOriginal); // Use the correct ID
    // Check if save actually worked - essential for montage later
    if (!File.exists(pathOriginal)) {
         print("  ERROR: Failed to save OriginalForMontage image! Path: " + pathOriginal);
         // Decide how to handle this? Maybe remove the ORIGINAL tag from paths?
         // For now, just print error. Montage creation might fail later.
    } else {
         print("  DEBUG: Successfully saved OriginalForMontage image.");
         if (paths != "") paths += "|";
	     paths += "ORIGINAL:" + pathOriginal; // Add path ONLY if save succeeded
    }


    // --- Cleanup: Close the image window ONLY if it was created by cropping ---
    if (didCrop) {
        print("  DEBUG: Closing cropped image window (ID: " + currentImgID + ")");
        closeImage(currentImgID); // Close the window associated with currentImgID
    } else {
         print("  DEBUG: Not closing original image window (ID: " + currentImgID + ")");
    }
    // If no cropping occurred, currentImgID is the original imgID passed in,
    // which should NOT be closed here (it's closed by runMacro if in batch mode).

    print("  DEBUG: Exiting processSingleImage for initial image: " + originalTitle + ". Accumulated paths: " + paths);
	return paths; // Return all generated paths
}

// ==========================================================
// Segmentation Functions (Should not need globals other than thresh_dots)
// ==========================================================

function runTraditionalSegmentation(sourceImgID, outputDir, baseName) {
	print("Running Traditional Segmentation...");
	var methods = newArray("Huang", "Percentile", "MinError(I)", "Triangle", "Li", "Otsu", "MaxEntropy", "RenyiEntropy"); // Local
	var methodFlags = newArray("ignore_white white", "ignore_white white", "ignore_white white", "ignore_white white", "ignore_white white", "ignore_white white", "ignore_white white", "ignore_white white"); // Local
	var pathList = ""; // Local

	for (var i = 0; i < methods.length; i++) { // Local i
		var method = methods[i]; // Local
		var flags = methodFlags[i]; // Local
		var outputPath = outputDir + baseName + "_T" + (i + 1) + "_" + method + ".tif"; // Local

		var dupID = duplicateImage(sourceImgID, baseName + "_Trad_" + method + "_Processing"); // Local
		if (dupID < 0) continue;

		runThreshold(dupID, method, flags); // runThreshold uses global thresh_dots
		postProcessBinaryImage(dupID); // postProcess uses globals for settings
		saveImage(dupID, outputPath);
		closeImage(dupID);

		if (pathList != "") pathList += "|";
		pathList += "TRAD:" + outputPath;
	}
	print("Finished Traditional Segmentation.");
	return pathList;
}

// ==========================================================
// Segmentation Functions (with explicit selections)
// ==========================================================

function runSrmSegmentation(sourceImgID, outputDir, baseName) {
    // Uses global SRM_Q_VALUE constants & thresh_dots
    print("Running Statistical Region Merging (SRM) based Segmentation...");
    var pathList = ""; // Local accumulator for output paths

    // --- Generate Base SRM Image 1 (Q25 -> Q12) ---
    print("  Generating SRM Base 1 (Q=" + SRM_Q_VALUE_1 + " then Q=" + SRM_Q_VALUE_2 + ")...");
    var srmBase1_ID = duplicateImage(sourceImgID, baseName + "_SRM_Base1_Processing"); // Call duplicate utility
    if (srmBase1_ID == 0) { // Check if duplication failed (returns 0 on failure)
        print("  ERROR [SRM]: Failed to create srmBase1 duplicate. Skipping SRM Base 1 processing.");
        return ""; // Return empty path list if base creation fails
    }
    // Explicitly select the new base image and wait
    selectImage(srmBase1_ID); wait(50);
    if (getImageID() != srmBase1_ID) { print("  ERROR [SRM]: Failed to select srmBase1_ID after creation!"); closeImage(srmBase1_ID); return ""; }
    print("  DEBUG [SRM]: Running SRM Q="+SRM_Q_VALUE_1+" on selected ID: " + srmBase1_ID);
    run("Statistical Region Merging", "q=" + SRM_Q_VALUE_1 + " showaverages");
    run("8-bit");
    // Re-select just in case focus changed, and wait
    selectImage(srmBase1_ID); wait(50);
    if (getImageID() != srmBase1_ID) { print("  ERROR [SRM]: Failed to re-select srmBase1_ID!"); closeImage(srmBase1_ID); return ""; }
    print("  DEBUG [SRM]: Running SRM Q="+SRM_Q_VALUE_2+" on selected ID: " + srmBase1_ID);
    run("Statistical Region Merging", "q=" + SRM_Q_VALUE_2 + " showaverages");
    run("8-bit");
    print("  DEBUG [SRM]: Finished creating srmBase1 (ID: " + srmBase1_ID + ")");
    // Optional save of intermediate base: saveImage(srmBase1_ID, outputDir + baseName + "_SRM_Base1_Intermediate.tif");


    // --- Generate Base SRM Image 2 (Q50 -> Q10) ---
    print("  Generating SRM Base 2 (Q=50 then Q=" + SRM_Q_VALUE_3 + ")...");
    // We duplicate from the *original* source image again
    var srmBase2_ID = duplicateImage(sourceImgID, baseName + "_SRM_Base2_Processing");
    if (srmBase2_ID == 0) { // Check if duplication failed
        print("  ERROR [SRM]: Failed to create srmBase2 duplicate. Skipping SRM Base 2 processing.");
        closeImage(srmBase1_ID); // Clean up base 1 if base 2 fails
        return ""; // Return empty path list
    }
    // Explicitly select the new base image and wait
    selectImage(srmBase2_ID); wait(50);
    if (getImageID() != srmBase2_ID) { print("  ERROR [SRM]: Failed to select srmBase2_ID after creation!"); closeImage(srmBase1_ID); closeImage(srmBase2_ID); return ""; }
    print("  DEBUG [SRM]: Running SRM Q=50 on selected ID: " + srmBase2_ID);
	run("Statistical Region Merging", "q=" + 50 + " showaverages");
	run("8-bit");
    // Re-select just in case focus changed, and wait
    selectImage(srmBase2_ID); wait(50);
    if (getImageID() != srmBase2_ID) { print("  ERROR [SRM]: Failed to re-select srmBase2_ID!"); closeImage(srmBase1_ID); closeImage(srmBase2_ID); return ""; }
    print("  DEBUG [SRM]: Running SRM Q="+SRM_Q_VALUE_3+" on selected ID: " + srmBase2_ID);
	run("Statistical Region Merging", "q=" + SRM_Q_VALUE_3 + " showaverages");
	run("8-bit");
    print("  DEBUG [SRM]: Finished creating srmBase2 (ID: " + srmBase2_ID + ")");
    // Optional save of intermediate base: saveImage(srmBase2_ID, outputDir + baseName + "_SRM_Base2_Intermediate.tif");


	// --- Apply Thresholding Methods ---
	var methods = newArray("Huang", "MinError(I)", "Percentile", "Triangle"); // Local
	var methodFlags = newArray("ignore_white white", "ignore_white white", "white", "white"); // Local

	// Apply to srmBase1 (ID = srmBase1_ID)
	print("  Thresholding SRM Base 1 (ID " + srmBase1_ID + ")...");
	for (var i = 0; i < methods.length; i++) { // Local i, method, flags, outputPath, dupID
		var method = methods[i];
		var flags = methodFlags[i];
		var outputPath = outputDir + baseName + "_S" + (i + 1) + "_SRM" + SRM_Q_VALUE_1 + "-" + SRM_Q_VALUE_2 + "_" + method + ".tif";

        // Duplicate the SRM BASE image (srmBase1_ID) for this specific threshold
		var dupID = duplicateImage(srmBase1_ID, baseName + "_SRM1_" + method + "_Processing");
		if (dupID == 0) { // Check failure
            print("    ERROR [SRM Threshold]: Failed to duplicate srmBase1 for method " + method + ". Skipping.");
            continue; // Skip this threshold method
        }
        print("    DEBUG [SRM Threshold]: Created threshold duplicate ID: " + dupID + " for method " + method);

        // --- Process this specific duplicate ---
        selectImage(dupID); wait(50); // <<< Select the threshold duplicate
        if(getImageID() != dupID) { print("    ERROR [SRM Threshold]: Failed selection for ID " + dupID); closeImage(dupID); continue; }
        print("    DEBUG [SRM Threshold]: Running threshold " + method + " on selected ID: " + dupID);
		runThreshold(dupID, method, flags); // runThreshold selects internally now

        selectImage(dupID); wait(50); // <<< Select before postProcess
        if(getImageID() != dupID) { print("    ERROR [SRM Threshold]: Failed selection for ID " + dupID); closeImage(dupID); continue; }
        print("    DEBUG [SRM Threshold]: Running postProcess on selected ID: " + dupID);
		postProcessBinaryImage(dupID); // postProcess selects internally now

        selectImage(dupID); wait(50); // <<< Select before save
        if(getImageID() != dupID) { print("    ERROR [SRM Threshold]: Failed selection for ID " + dupID); closeImage(dupID); continue; }
        print("    DEBUG [SRM Threshold]: Saving selected ID: " + dupID + " to " + outputPath);
		saveImage(dupID, outputPath); // saveImage selects internally now

		closeImage(dupID); // Close this specific thresholded duplicate
        print("    DEBUG [SRM Threshold]: Closed ID: " + dupID);
        // --- End processing specific duplicate ---

		if (pathList != "") pathList += "|";
		pathList += "SRM:" + outputPath; // Add successfully created path
	} // End thresholding loop for srmBase1


	// Apply to srmBase2 (ID = srmBase2_ID) - Similar loop structure
	print("  Thresholding SRM Base 2 (ID " + srmBase2_ID + ")...");
	for (var i = 0; i < methods.length; i++) { // Local i, method, flags, outputPath, dupID
		var method = methods[i];
		var flags = methodFlags[i];
		var outputPath = outputDir + baseName + "_S" + (i + 5) + "_SRM50-" + SRM_Q_VALUE_3 + "_" + method + ".tif"; // Index starts at 5

        // Duplicate the second SRM BASE image (srmBase2_ID)
		var dupID = duplicateImage(srmBase2_ID, baseName + "_SRM2_" + method + "_Processing");
		if (dupID == 0) {
             print("    ERROR [SRM Threshold]: Failed to duplicate srmBase2 for method " + method + ". Skipping.");
             continue;
        }
        print("    DEBUG [SRM Threshold]: Created threshold duplicate ID: " + dupID + " for method " + method);

        // --- Process this specific duplicate ---
        selectImage(dupID); wait(50);
        if(getImageID() != dupID) { print("    ERROR [SRM Threshold]: Failed selection for ID " + dupID); closeImage(dupID); continue; }
        print("    DEBUG [SRM Threshold]: Running threshold " + method + " on selected ID: " + dupID);
		runThreshold(dupID, method, flags);

        selectImage(dupID); wait(50);
        if(getImageID() != dupID) { print("    ERROR [SRM Threshold]: Failed selection for ID " + dupID); closeImage(dupID); continue; }
        print("    DEBUG [SRM Threshold]: Running postProcess on selected ID: " + dupID);
		postProcessBinaryImage(dupID);

        selectImage(dupID); wait(50);
        if(getImageID() != dupID) { print("    ERROR [SRM Threshold]: Failed selection for ID " + dupID); closeImage(dupID); continue; }
        print("    DEBUG [SRM Threshold]: Saving selected ID: " + dupID + " to " + outputPath);
		saveImage(dupID, outputPath);

		closeImage(dupID);
        print("    DEBUG [SRM Threshold]: Closed ID: " + dupID);
        // --- End processing specific duplicate ---

		if (pathList != "") pathList += "|";
		pathList += "SRM:" + outputPath;
	} // End thresholding loop for srmBase2


	// --- Cleanup Base SRM Images ---
	print("  DEBUG [SRM]: Cleaning up base images ID " + srmBase1_ID + " and " + srmBase2_ID);
	closeImage(srmBase1_ID);
	closeImage(srmBase2_ID);

	print("Finished SRM Segmentation. Accumulated paths: " + pathList);
	return pathList;
} // End runSrmSegmentation

// --- ======================================================= ---

function runMixedSegmentation(sourceImgID, outputDir, baseName) {
    // Uses global SRM_Q_VALUE_1 & thresh_dots
    print("Running Mixed Segmentation...");
    var pathList = ""; // Local accumulator

    // --- Generate Base SRM Image (Q=SRM_Q_VALUE_1) ---
    print("  Generating SRM Base (Q=" + SRM_Q_VALUE_1 + ")...");
    var srmBaseID = duplicateImage(sourceImgID, baseName + "_SRM_MixedBase_Processing"); // Local ID
    if (srmBaseID == 0) { // Check failure
        print("  ERROR [Mixed]: Failed to create SRM base duplicate. Skipping Mixed SRM+Threshold steps.");
        // Still proceed to Direct Threshold steps below if srmBaseID is invalid
    } else {
        // Apply SRM to the duplicate
        selectImage(srmBaseID); wait(50); // Select the new duplicate
        if(getImageID() != srmBaseID) { print("  ERROR [Mixed]: Failed selection for srmBaseID " + srmBaseID); closeImage(srmBaseID); srmBaseID = 0; } // Mark as failed if select fails
        else {
             print("  DEBUG [Mixed]: Running SRM Q="+SRM_Q_VALUE_1+" on selected ID: " + srmBaseID);
	         run("Statistical Region Merging", "q=" + SRM_Q_VALUE_1 + " showaverages");
	         run("8-bit");
             print("  DEBUG [Mixed]: Finished creating SRM Base (ID: " + srmBaseID + ")");
             // Optional save: saveImage(srmBaseID, outputDir + baseName + "_SRM_MixedBase_Q" + SRM_Q_VALUE_1 + ".tif");
        }
    }


	// --- Apply Thresholding Methods ---
	var methods = newArray("Huang", "MinError(I)", "Percentile", "Triangle"); // Local arrays
	var methodFlagsDirect = newArray("ignore_white white", "white", "white", "white");
	var methodFlagsSRM = newArray("ignore_white white", "ignore_white white", "white", "white");

	for (var i = 0; i < methods.length; i++) { // Local loop variables
		var method = methods[i];
		var flagsDirect = methodFlagsDirect[i];
		var flagsSRM = methodFlagsSRM[i];
		var outputPrefix = "M" + (i * 2 + 1); // M1, M3, M5, M7 for SRM+Thresh
		var outputPrefixDirect = "M" + (i * 2 + 2); // M2, M4, M6, M8 for Direct Thresh

		// --- 1. Apply Threshold to SRM Base (if srmBaseID is valid) ---
        if (srmBaseID != 0) {
            print("  Processing Mixed SRM+Threshold for method: " + method);
            var outputPathSRM = outputDir + baseName + "_" + outputPrefix + "_SRM" + SRM_Q_VALUE_1 + "+" + method + ".tif"; // Local path
            var dupSrmID = duplicateImage(srmBaseID, baseName + "_Mix_SRM_" + method + "_Processing"); // Local ID
            if (dupSrmID != 0) { // Check if duplicate succeeded
                 print("    DEBUG [Mixed SRM+Thresh]: Created duplicate ID: " + dupSrmID);
                 // Process this duplicate
                 selectImage(dupSrmID); wait(50);
                 if(getImageID() != dupSrmID) { print("    ERROR [Mixed SRM+Thresh]: Failed selection for ID " + dupSrmID); closeImage(dupSrmID); }
                 else {
                    print("    DEBUG [Mixed SRM+Thresh]: Running threshold " + method + " on selected ID: " + dupSrmID);
			        runThreshold(dupSrmID, method, flagsSRM);

                    selectImage(dupSrmID); wait(50);
                    if(getImageID() != dupSrmID) { print("    ERROR [Mixed SRM+Thresh]: Failed selection for ID " + dupSrmID); closeImage(dupSrmID); }
                    else {
                        print("    DEBUG [Mixed SRM+Thresh]: Running postProcess on selected ID: " + dupSrmID);
			            postProcessBinaryImage(dupSrmID);

                        selectImage(dupSrmID); wait(50);
                         if(getImageID() != dupSrmID) { print("    ERROR [Mixed SRM+Thresh]: Failed selection for ID " + dupSrmID); closeImage(dupSrmID); }
                         else {
                              print("    DEBUG [Mixed SRM+Thresh]: Saving selected ID: " + dupSrmID + " to " + outputPathSRM);
			                  saveImage(dupSrmID, outputPathSRM);
                              if (pathList != "") pathList += "|";
			                  pathList += "MIXED:" + outputPathSRM; // Add path if successful
                         }
                    }
                 }
                 closeImage(dupSrmID); // Close the SRM+Threshold duplicate
                 print("    DEBUG [Mixed SRM+Thresh]: Closed ID: " + dupSrmID);
            } else {
                 print("    ERROR [Mixed SRM+Thresh]: Failed to duplicate srmBaseID for method " + method + ". Skipping.");
            }
        } else if (i==0) { // Only print this message once if SRM Base failed
             print("  INFO [Mixed]: Skipping all SRM+Threshold steps because SRM Base creation failed.");
        }
        // --- End SRM+Threshold Step ---


		// --- 2. Apply Threshold Directly to Source ---
        print("  Processing Mixed Direct Threshold for method: " + method);
		var outputPathDirect = outputDir + baseName + "_" + outputPrefixDirect + "_Direct_" + method + ".tif"; // Local path
		var dupDirectID = duplicateImage(sourceImgID, baseName + "_Mix_Direct_" + method + "_Processing"); // Local ID
		if (dupDirectID != 0) { // Check duplicate success
            print("    DEBUG [Mixed Direct]: Created duplicate ID: " + dupDirectID);
            // Process this duplicate
            selectImage(dupDirectID); wait(50);
            if(getImageID() != dupDirectID) { print("    ERROR [Mixed Direct]: Failed selection for ID " + dupDirectID); closeImage(dupDirectID); }
            else {
                print("    DEBUG [Mixed Direct]: Running threshold " + method + " on selected ID: " + dupDirectID);
			    runThreshold(dupDirectID, method, flagsDirect);

                selectImage(dupDirectID); wait(50);
                 if(getImageID() != dupDirectID) { print("    ERROR [Mixed Direct]: Failed selection for ID " + dupDirectID); closeImage(dupDirectID); }
                 else {
                    print("    DEBUG [Mixed Direct]: Running postProcess on selected ID: " + dupDirectID);
			        postProcessBinaryImage(dupDirectID);

                    selectImage(dupDirectID); wait(50);
                    if(getImageID() != dupDirectID) { print("    ERROR [Mixed Direct]: Failed selection for ID " + dupDirectID); closeImage(dupDirectID); }
                    else {
                        print("    DEBUG [Mixed Direct]: Saving selected ID: " + dupDirectID + " to " + outputPathDirect);
			            saveImage(dupDirectID, outputPathDirect);
                        if (pathList != "") pathList += "|";
			            pathList += "MIXED:" + outputPathDirect; // Add path if successful
                    }
                 }
            }
			closeImage(dupDirectID); // Close the Direct Threshold duplicate
            print("    DEBUG [Mixed Direct]: Closed ID: " + dupDirectID);
		} else {
             print("    ERROR [Mixed Direct]: Failed to duplicate sourceImgID for method " + method + ". Skipping.");
        }
        // --- End Direct Threshold Step ---

	} // End loop through methods

	// --- Cleanup Base SRM Image (if it was created) ---
    if (srmBaseID != 0) {
        print("  DEBUG [Mixed]: Cleaning up base SRM image ID " + srmBaseID);
	    closeImage(srmBaseID);
    }

	print("Finished Mixed Segmentation. Accumulated paths: " + pathList);
	return pathList;
} // End runMixedSegmentation


// ==========================================================
// Post-Processing Function for Binary Images
// ==========================================================
// ==========================================================
// Post-Processing Function for Binary Images
// ==========================================================
function postProcessBinaryImage(imgID) {
    // Uses global POST_PROCESS_OUTLIER constants

    // Ensure the correct image is active
    print("    DEBUG [PostProcess]: Starting post-processing for ID: " + imgID);
    selectImage(imgID);
    wait(50); // Short wait after select
    if(getImageID() != imgID) {
        print("    ERROR [PostProcess]: Failed selection for ID " + imgID + ". Aborting post-processing.");
        return; // Exit function if selection failed
    }
    print("    DEBUG [PostProcess]: Image ID " + imgID + " selected.");

    // 1. Fill Holes
    print("    DEBUG [PostProcess]: Filling holes...");
	run("Fill Holes");

	// 2. Despeckle Loop
    print("    DEBUG [PostProcess]: Despeckling...");
	// Using white pixel count stabilization
	getHistogram(values, counts, 256); // values/counts are local
	if (counts.length > 0) {
		var pixelCountBefore = counts[counts.length - 1]; // Count white pixels (255)
		var currentCount = pixelCountBefore; // Local loop vars
		var previousCount;
		var iterations = 0;
		var maxIterations = 10; // Safety break
		do {
			previousCount = currentCount;
			run("Despeckle");
            wait(50); // Add small wait after potentially modifying command
			getHistogram(values, counts, 256);
            if (counts.length > 0) {
			    currentCount = counts[counts.length-1];
            } else {
                 print("    WARNING [PostProcess]: getHistogram failed during despeckle loop.");
                 currentCount = previousCount; // Stop loop if histogram fails
            }
			iterations++;
		} while (currentCount != previousCount && iterations < maxIterations);
		if(iterations == maxIterations) print("    WARNING [PostProcess]: Despeckle loop reached max iterations on " + getTitle());
	} else {
		print("    WARNING [PostProcess]: Could not get initial histogram for despeckle loop on " + getTitle());
	}


	// 3. Remove Outliers
    print("    DEBUG [PostProcess]: Removing outliers...");
	run("Remove Outliers...", "radius=" + POST_PROCESS_OUTLIER_RADIUS + " threshold=" + POST_PROCESS_OUTLIER_THRESHOLD + " which=Dark");
	run("Remove Outliers...", "radius=" + POST_PROCESS_OUTLIER_RADIUS + " threshold=" + POST_PROCESS_OUTLIER_THRESHOLD + " which=Bright");
	run("Remove Outliers...", "radius=" + POST_PROCESS_OUTLIER_RADIUS + " threshold=" + POST_PROCESS_OUTLIER_THRESHOLD + " which=Dark"); // Repeated as in original
	run("Remove Outliers...", "radius=" + POST_PROCESS_OUTLIER_RADIUS + " threshold=" + POST_PROCESS_OUTLIER_THRESHOLD + " which=Bright");

	// 4. Erode/Dilate
    print("    DEBUG [PostProcess]: Erode/Dilate...");
	run("Erode");
	run("Dilate");

	// 5. Ensure Binary and Correct Inversion (Black Objects=0, White Background=255)
    print("    DEBUG [PostProcess]: Ensuring binary and correct inversion...");
	run("Make Binary"); // Ensure it's truly binary
    wait(50); // Wait after make binary

    // Set measurements *before* calling getStatistics
	run("Set Measurements...", "mean redirect=None decimal=3"); // Ensure mean is calculated

    // Correct call to getStatistics - variable names are implicitly set
    getStatistics(area, mean, min, max, stdDev); // Use stdDev

    // Check if mean was successfully calculated (it might be NaN if measurement failed)
    // Need isNaN() function if available, otherwise check if mean equals itself
    // Note: IJM might not have a built-in isNaN(). A common check is (mean!=mean).
    var meanIsNaN = (mean != mean); // Check for NaN
    if(meanIsNaN) {
         print("    WARNING [PostProcess]: Failed to get valid 'mean' statistic for inversion check on " + getTitle() + ". Skipping inversion.");
    } else {
        print("    DEBUG [PostProcess]: Mean calculated: " + mean);
	    if (mean > 128) { // If mean is high, objects are likely white (255)
            print("    DEBUG [PostProcess]: Inverting image (mean > 128).");
		    run("Invert"); // Invert to make objects black (0)
	    } else {
             print("    DEBUG [PostProcess]: Not inverting image (mean <= 128).");
        }
    }

	resetThreshold(); // Clear any threshold display remaining
    print("    DEBUG [PostProcess]: Finished post-processing for ID: " + imgID);
}

// ==========================================================
// Montage Creation Function
// ==========================================================
function createMontagesIfNeeded(outputPathsString, originalProcessedImgID) {
    // Accesses globals: dirOutputBase, TLCB_None, TRCB_Trad, BLCB_SRM, BRCB_Mix
    // Accesses global MONTAGE constants
	print("DEBUG: Entering createMontagesIfNeeded...");
	if (TLCB_None == 1 || outputPathsString == "null" || outputPathsString == "") {
        print("DEBUG: Skipping montage creation (None selected or no paths).");
		return;
	}

    if (dirOutputBase == "null" || dirOutputBase == "") {
        print("ERROR: Output directory (dirOutputBase) not set in createMontagesIfNeeded.");
        return;
    }
	var dirMontage = dirOutputBase + "Montage Images" + File.separator; // Local

	var allPaths = split(outputPathsString, "|"); // Local arrays/vars
	var originalPath = "";
	var tradPaths = newArray();
	var srmPaths = newArray();
	var mixedPaths = newArray();

	for (var i = 0; i < allPaths.length; i++) { // Local i, p
		var p = allPaths[i];
		if (startsWith(p, "ORIGINAL:")) { originalPath = replace(p, "ORIGINAL:", ""); }
		else if (startsWith(p, "TRAD:")) { tradPaths = Array.concat(tradPaths, replace(p, "TRAD:", "")); }
		else if (startsWith(p, "SRM:")) { srmPaths = Array.concat(srmPaths, replace(p, "SRM:", "")); }
		else if (startsWith(p, "MIXED:")) { mixedPaths = Array.concat(mixedPaths, replace(p, "MIXED:", "")); }
	}

	if (originalPath == "") {
		print("Error: Could not find path for original image for montage creation.");
		return; // Cannot proceed without original
	}
    print("DEBUG: Found original path for montage: " + originalPath);

	var baseName = removeExtension(getTitleFromPath(originalPath)); // Local baseName
	baseName = replace(baseName, "_OriginalForMontage", ""); // Clean up name
    baseName = replace(baseName, "_CroppedOrOriginal", ""); // Clean up name if None was chosen initially
    print("DEBUG: Base name for montage file: " + baseName);

	// Determine which montage(s) to create (local boolean flags)
	var createTradMontage = (TRCB_Trad == 1 && BLCB_SRM == 0 && BRCB_Mix == 0);
	var createSrmMontage = (TRCB_Trad == 0 && BLCB_SRM == 1 && BRCB_Mix == 0);
	var createMixedMontage = (TRCB_Trad == 0 && BLCB_SRM == 0 && BRCB_Mix == 1);
	var createTradSrmMontage = (TRCB_Trad == 1 && BLCB_SRM == 1 && BRCB_Mix == 0);
	var createTradMixedMontage = (TRCB_Trad == 1 && BLCB_SRM == 0 && BRCB_Mix == 1);
	var createSrmMixedMontage = (TRCB_Trad == 0 && BLCB_SRM == 1 && BRCB_Mix == 1);
	var createAllMontage = (TRCB_Trad == 1 && BLCB_SRM == 1 && BRCB_Mix == 1);

	setForegroundColor(MONTAGE_LABEL_COLOR_R, MONTAGE_LABEL_COLOR_G, MONTAGE_LABEL_COLOR_B);

    // Local vars: pathsToCombine, montagePath
	if (createMixedMontage) {
		print("Creating Mixed Montage...");
		var pathsToCombine = Array.concat(newArray(originalPath), mixedPaths);
		var montagePath = dirMontage + baseName + "_Mix_Montage.png";
		generateMontage(pathsToCombine, montagePath, 3, 3, MONTAGE_FONT_SIZE_SMALL);
	}
	if (createSrmMontage) {
		print("Creating SRM Montage...");
		var pathsToCombine = Array.concat(newArray(originalPath), srmPaths);
		var montagePath = dirMontage + baseName + "_SRM_Montage.png";
		generateMontage(pathsToCombine, montagePath, 3, 3, MONTAGE_FONT_SIZE_SMALL);
	}
	if (createTradMontage) {
		print("Creating Traditional Montage...");
		var pathsToCombine = Array.concat(newArray(originalPath), tradPaths);
		var montagePath = dirMontage + baseName + "_Trad_Montage.png";
		generateMontage(pathsToCombine, montagePath, 3, 3, MONTAGE_FONT_SIZE_SMALL);
	}
	if (createTradSrmMontage) {
		print("Creating Traditional & SRM Montage...");
		var pathsToCombine = Array.concat(newArray(originalPath), tradPaths, srmPaths);
		var montagePath = dirMontage + baseName + "_Trad&SRM_Montage.png";
		generateMontage(pathsToCombine, montagePath, 4, 4, MONTAGE_FONT_SIZE_MEDIUM);
	}
	if (createTradMixedMontage) {
		print("Creating Traditional & Mixed Montage...");
		var pathsToCombine = Array.concat(newArray(originalPath), tradPaths, mixedPaths);
		var montagePath = dirMontage + baseName + "_Trad&Mix_Montage.png";
		generateMontage(pathsToCombine, montagePath, 4, 4, MONTAGE_FONT_SIZE_MEDIUM);
	}
	if (createSrmMixedMontage) {
		print("Creating SRM & Mixed Montage...");
		var pathsToCombine = Array.concat(newArray(originalPath), srmPaths, mixedPaths);
		var montagePath = dirMontage + baseName + "_Mix&SRM_Montage.png";
		generateMontage(pathsToCombine, montagePath, 4, 4, MONTAGE_FONT_SIZE_MEDIUM);
	}
	if (createAllMontage) {
		print("Creating Traditional & SRM & Mixed Montage...");
		var pathsToCombine = Array.concat(newArray(originalPath), tradPaths, srmPaths, mixedPaths);
		var montagePath = dirMontage + baseName + "_Trad&Mix&SRM_Montage.png";
		generateMontage(pathsToCombine, montagePath, 5, 5, MONTAGE_FONT_SIZE_LARGE);
	}

	setForegroundColor(0, 0, 0); // Reset color
	print("Finished Montage Creation.");
}


// ==========================================================
// Utility Functions (Generally use local variables or arguments)
// ==========================================================

// --- generateMontage (Helper for Montage Creation) ---
// --- generateMontage (Helper for Montage Creation - Cleaned Up) ---
function generateMontage(pathsArray, montageOutputPath, columns, rows, fontSize) {
    print("  DEBUG [Montage]: Entering generateMontage for output: " + montageOutputPath);
    var idsToClose = newArray(); // Local array for IDs to close later
    var titles = ""; // <<<--- Use this variable to collect titles for the stack command ---<<<

    if(pathsArray.length < 2) {
        print("  WARNING [Montage]: Not enough images provided (" + pathsArray.length + "). Skipping montage: " + montageOutputPath);
        return;
    }
    print("  DEBUG [Montage]: Target number of images: " + pathsArray.length);

    // --- Open images and collect IDs/Titles ---
    print("  DEBUG [Montage]: Opening images for stack...");
    for (var i = 0; i < pathsArray.length; i++) {
        var currentPathToOpen = pathsArray[i];
        print("    DEBUG [Montage Open]: Processing path [" + i + "]: '" + currentPathToOpen + "'");

        if (currentPathToOpen == "" || !File.exists(currentPathToOpen)) {
             print("    ERROR [Montage Open]: Path invalid or file does not exist: '" + currentPathToOpen + "'. Skipping.");
             continue;
        }

        var id = openImageAndGetID(currentPathToOpen); // Use the latest open function

        if (id != 0) { // Check if ID is valid (non-zero)
            // Get title *after* potential selection within openImageAndGetID ensures correct title
            selectImage(id); // Ensure it's selected before getTitle
            var currentTitle = getTitle();
            print("    DEBUG [Montage Open]: Successfully obtained ID=" + id + ", Title='" + currentTitle + "'");
            idsToClose = Array.concat(idsToClose, id);
            titles += currentTitle + " "; // <<<--- Append title to the 'titles' string ---<<<

            // Invert segmented results for display?
            if (!endsWith(currentPathToOpen,"_OriginalForMontage.tif") && !endsWith(currentPathToOpen,"_CroppedOrOriginal.tif")) {
                 selectImage(id); run("Invert");
                 // print("    DEBUG [Montage Open]: Inverted segmented result: " + currentTitle);
            }
        } else {
            print("    ERROR [Montage Open]: openImageAndGetID failed (returned 0) for: " + currentPathToOpen);
        }
    } // End for loop opening images

    print("  DEBUG [Montage]: Number of images successfully opened for stack: " + idsToClose.length);
    if (idsToClose.length < 2) {
        print("  WARNING [Montage]: Need at least two images successfully opened to create a montage. Skipping: " + montageOutputPath);
        for(var i=0; i<idsToClose.length; i++) closeImage(idsToClose[i]);
        return;
    }

    // --- Create Stack ---
    // Ensure titles string isn't empty and trim trailing space
    titles = trim(titles);
    if (titles == "") {
          print("  ERROR [Montage]: No titles collected for stack. Aborting montage.");
          for(var i=0; i<idsToClose.length; i++) closeImage(idsToClose[i]);
          return;
     }
    print("  DEBUG [Montage]: Creating stack from titles: [" + titles + "]");
    run("Images to Stack", "titles=[" + titles + "] use"); // <<<--- Use the correct 'titles' variable ---<<<
    wait(200);
    var stackID = getImageID();

    // ... (Rest of the function remains the same: check stackID, Make Montage, save, cleanup) ...

    if (stackID == 0) {
         print("  ERROR [Montage]: Failed to create stack window (getImageID returned 0). Aborting montage.");
         for(var i=0; i<idsToClose.length; i++) closeImage(idsToClose[i]); // Close inputs
         return;
    }
     print("  DEBUG [Montage]: Stack created successfully with ID: " + stackID);

	// --- Create Montage visualization ---
    print("  DEBUG [Montage]: Creating montage visualization...");
	selectImage(stackID);
	wait(50);
    if(getImageID() != stackID) { print("  ERROR [Montage]: Failed to select Stack window!"); closeImage(stackID); for(var i=0; i<idsToClose.length; i++) closeImage(idsToClose[i]); return; }

    run("RGB Color");
	var maxImages = columns * rows;
	var numSlices = nSlices();
	print("  DEBUG [Montage]: Stack has " + numSlices + " slices. Grid is " + columns + "x" + rows + ".");
    if (numSlices > maxImages) {
		print("  WARNING [Montage]: More images ("+numSlices+") than fit in montage grid ("+maxImages+"). Showing first " + maxImages + ".");
	}

    run("Make Montage...", "columns=" + columns + " rows=" + rows + " scale=" + MONTAGE_SCALE +
		" first=1 last=" + minf(numSlices, maxImages) + " increment=1 border=" + MONTAGE_BORDER +
		" font=" + fontSize + " label use");
	wait(200);
	var montageID = getImageID();

    // --- Save and Cleanup ---
	if (montageID != 0 && montageID != stackID) {
        print("  DEBUG [Montage]: Montage window created with ID: " + montageID);
		saveImage(montageID, montageOutputPath);
		print("  Saved montage: " + montageOutputPath);
		closeImage(montageID);
	} else {
		print("  ERROR [Montage]: Failed to create or get valid ID for montage window. MontageID=" + montageID + ", StackID=" + stackID);
        if (montageID != stackID && isOpen(montageID)) closeImage(montageID);
	}

    print("  DEBUG [Montage]: Cleaning up stack window ID: " + stackID);
    if(isOpen(stackID)) closeImage(stackID);
    print("  DEBUG [Montage]: Cleaning up original input image windows...");
	for (var i = 0; i < idsToClose.length; i++) {
		closeImage(idsToClose[i]);
	}
    print("  DEBUG [Montage]: Finished generateMontage function.");
} // End generateMontage

// --- Get Image ID Safely ---
function getCurrentImageID() { // Returns local value
	var id = getImageID();
	if (nImages() == 0 || id < 0) {
		print("Error: No image is currently open.");
		return -1;
	}
	return id;
}

// --- Open Image and Return ID ---
// --- Open Image and Return ID (Select by Title) ---
function openImageAndGetID(path) {
    print("  DEBUG: Opening path: " + path);
    var expectedTitle = getTitleFromPath(path);
    var forwardSlashPath = replace(path, "\\", "/");
    print("  DEBUG: Using forward slashes: " + forwardSlashPath + ", expecting title: " + expectedTitle);

    open(forwardSlashPath);
    wait(300); // Pause for window to appear

    // --- Select by Title and THEN get ID ---
    var id = 0; // Default to failure
    if (isOpen(expectedTitle)) { // Use isOpen(title) utility
        print("  DEBUG: Window with title '" + expectedTitle + "' found. Selecting...");
        selectWindow(expectedTitle);
        wait(100); // Pause after select
        id = getImageID(); // Get ID of selected window
        if (id != 0) {
            print("  DEBUG: Selected by title. ID is: " + id);
        } else {
            print("  ERROR: Selected window '" + expectedTitle + "' but failed to get valid ID (got 0).");
        }
    } else {
        // Sometimes ImageJ adds "-1", check for that too
        var alternateTitle = expectedTitle + "-1";
        if (isOpen(alternateTitle)) { // Use isOpen(title)
            print("  DEBUG: Window with title '" + alternateTitle + "' found. Selecting...");
            selectWindow(alternateTitle);
            wait(100);
            id = getImageID();
            if (id != 0) {
                print("  DEBUG: Selected by alternate title. ID is: " + id);
            } else {
                 print("  ERROR: Selected window '" + alternateTitle + "' but failed to get valid ID (got 0).");
            }
        } else {
            print("  ERROR: Window with title '" + expectedTitle + "' or '" + alternateTitle + "' not found after open.");
        }
    }

    return id; // Return the ID obtained (negative is OK, 0 indicates failure)
}

// --- getTitleFromPath ---
function getTitleFromPath(path) { // Returns local value
    var sep = File.separator; // Local vars
    var lastSep = lastIndexOf(path, sep);
    // Also check for forward slash if used in path directly
    if (lastSep < 0) lastSep = lastIndexOf(path, "/");
    if (lastSep >= 0) {
        return substring(path, lastSep + 1);
    } else { return path; }
}

// --- isOpen (checking by TITLE string) ---
function isOpen(title) {
    var list = getList("image.titles"); // Use local var list
    found = false; // Local flag
    for (var i = 0; i < list.length; i++) { // Local i
        if (list[i] == title) {
            found = true;
            break; // Found it, exit loop
        }
    }
    return found;
}

// --- Duplicate Image Safely ---
function duplicateImage(sourceID, newTitle) { // Returns local value
    // We removed the isOpen check earlier, maybe that was needed?
	print("  DEBUG [Duplicate]: Attempting to duplicate ID " + sourceID + " to '" + newTitle + "'");
	selectImage(sourceID);
    // Maybe add a tiny wait after select?
    wait(50);
	var activeID = getImageID();
    var activeTitle = getTitle(); // Get title just in case ID is wrong
    if (activeID != sourceID) {
        print("  ERROR [Duplicate]: Failed to select source ID " + sourceID + ". Active ID is " + activeID + " ('" + activeTitle + "'). Cannot duplicate.");
        return 0; // Return 0 for failure
    }
    print("  DEBUG [Duplicate]: Successfully selected source: ID=" + sourceID + ", Title='" + activeTitle + "'");

	run("Duplicate...", "title=[" + newTitle + "]");
    wait(100); // Add wait after duplicate command
	var dupID = getImageID(); // Get ID of the *newly created* duplicate

	if (dupID == sourceID || dupID == 0) { // Check if duplication failed or returned original ID/invalid ID
		print("  ERROR [Duplicate]: Failed to create valid duplicate window. dupID=" + dupID + ", sourceID=" + sourceID + ". Title attempted: " + newTitle);
        // Check if a window with the new title *does* exist anyway?
        if (isOpen(newTitle)) { // Use isOpen(title)
            print("  WARNING [Duplicate]: Duplicate failed, but window '" + newTitle + "' exists?");
            // Try selecting and getting ID again?
            selectWindow(newTitle); wait(50); dupID = getImageID();
            print("  WARNING [Duplicate]: ID after selecting existing title: " + dupID);
            if (dupID == sourceID || dupID == 0) return -1; // Still failed
        } else {
             return -1; // Truly failed
        }
	}
    print("  DEBUG [Duplicate]: Successfully duplicated ID " + sourceID + " to new ID " + dupID + " ('" + getTitle() + "')");
	return dupID; // Return the ID of the new duplicate window
}

// --- Save Image Safely ---
function saveImage(imgID, outputPath) {

	selectImage(imgID);
	saveAs("Tiff", outputPath);
}

// --- Close Image Safely by ID ---
function closeImage(imgID) {
	if (isOpen(imgID)) {
		selectImage(imgID);
		run("Close");
	}
}

// --- Remove file extension ---
function removeExtension(filename) { // Returns local value
	var dotIndex = lastIndexOf(filename, "."); // Local var
	if (dotIndex > 0) {
		return substring(filename, 0, dotIndex);
	} else {
		return filename;
	}
}


// --- Wrapper for run("Auto Threshold") ---
function runThreshold(imgID, method, flags) {
    // Uses global thresh_dots
	selectImage(imgID);
	run(thresh_dots, "method=" + method + " " + flags);
    // If threshold fails, script might halt or proceed with unthresholded image.
}

// --- Helper to find min of two numbers ---
function minf(a, b) { // Returns local value
	if (a < b) return a;
	else return b;
}
// --- End of Macro ---
