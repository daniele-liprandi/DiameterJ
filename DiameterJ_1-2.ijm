// Macro: DiameterJ Analysis (Refactored)
// Performs fiber diameter, orientation, pore, and intersection analysis.

// --- Configuration Variables ---
// (These could be adjusted if needed)
var DEFAULT_SCALE_PIXELS = 306;
var DEFAULT_SCALE_UNITS = 100;
var DEFAULT_SCALE_UNIT_NAME = "Microns"; // Or um, etc.
var DEFAULT_MIN_RADIUS_PIXELS = 1;
var DEFAULT_MAX_RADIUS_PIXELS = 255;
var PARTICLE_ANALYSIS_MIN_SIZE = 10; // Min size for pore analysis
var MONTAGE_SCALE_DIAMJ = 1.0;
var MONTAGE_BORDER_DIAMJ = 5;
var MONTAGE_FONT_DIAMJ = 25;
var WAIT_AFTER_OPEN = 300; // ms pause after opening image
var WAIT_AFTER_CMD = 100; // ms pause after commands like duplicate, select, run

// --- Global Variable Declarations ---
// (Set by dialog, used by other functions)
var choice_orien;
var unit_conv;
var unit_pix;
var unit_real;
var unit_meas_string; // e.g., "um" or "pixel"
var R_Loc;
var lowT; // Lower threshold for radius location
var highT; // Upper threshold for radius location
var Batch_analysis;
var batch_combo;
var dirOutputBase; // Main output directory

// --- Main Execution ---
runDiameterJMacro();

// ==========================================================
// Main Function
// ==========================================================
function runDiameterJMacro() {
	print("DEBUG: Starting DiameterJ Macro...");

	if (!getDiameterJUserInput()) {
		print("User cancelled Dialog.");
		return;
	}
	print("DEBUG: User input acquired.");

	var T1 = getTime(); // Local timing var

	if (Batch_analysis == "Yes") {
		// Batch Processing
		print("DEBUG: Starting Batch Processing...");
		var dirSource = getDirectory("Choose Source Directory"); // Local source dir
		if (dirSource == "null") { print("Batch mode cancelled."); return; }
		dirOutputBase = dirSource; // Set global output base for batch
		print("DEBUG: Output base set to: " + dirOutputBase);
		var list = getFileList(dirSource); // Local file list
		if (list.length == 0) { print("No image files found in: " + dirSource); return; }

		// setBatchMode(true); // Optional: Re-enable later if needed

		for (var i = 0; i < list.length; i++) { // Local loop counter i
			showProgress(i + 1, list.length);
			var filename = dirSource + list[i]; // Local full path
			var lowerCaseFilename = toLowerCase(filename); // Local lowercase path

			if (isSupportedImageFile(lowerCaseFilename)) {
				print("--------------------");
				print("Analyzing image [" + (i + 1) + "/" + list.length + "]: " + list[i]);

				// --- Open Image ---
				var imgID = openImageAndGetID_DJ(filename); // Use specific open func
				if (imgID == 0) { // Check for failure (0 from utility)
					print("  ERROR: Failed to open or get ID for " + list[i] + ". Skipping.");
					continue; // Skip to next file
				}
				print("  DEBUG: Image opened. ID: " + imgID + ", Title: " + getTitle());

				// --- Force Selection ---
				// Crucial step after opening to ensure context
				selectImage(imgID);
				wait(WAIT_AFTER_CMD);
				if (getImageID() != imgID) {
					print("  ERROR: Failed to select Image ID " + imgID + " after opening. Skipping.");
					closeImage_DJ(imgID); // Try to close
					continue;
				}
				print("  DEBUG: Image ID " + imgID + " successfully selected.");


				// --- Process Single Image ---
				var success = processSingleDiameterJImage(imgID); // Call main processing function

				if (!success) {
					print("  ERROR: Processing failed for image: " + list[i]);
				}

				// --- Close Image ---
				// Close the image window for this iteration
				print("  DEBUG: Attempting to close image window ID: " + imgID + " (File: " + list[i] + ")");
				closeImage_DJ(imgID); // Use specific close func

				print("Finished processing: " + list[i]);

			} // End file type check
		} // End for loop

		// setBatchMode(false); // Optional: Re-enable later if needed
		showProgress(1.0);

		// --- Optional Batch Combination ---
		if (batch_combo == "Yes") {
			print("--------------------");
			print("Starting Batch Combination...");
			runBatchCombination(); // Call function to combine results
			print("Finished Batch Combination.");
		}

	} else {
		// Single Image Processing
		print("DEBUG: Starting Single Image Processing...");
		var imgID = getImageID(); // Get currently active image
		if (imgID == 0) { print("ERROR: No image open for single analysis."); return; }
		var imgTitle = getTitle();
		print("DEBUG: Found active image: '" + imgTitle + "' (ID: " + imgID + ")");

		dirOutputBase = getDirectory("Choose Directory to Store Output Images In"); // Set global
		if (dirOutputBase == "null") { print("Single mode cancelled."); return; }
		print("DEBUG: Output base set to: " + dirOutputBase);

		// setBatchMode(true); // Optional

		print("--------------------");
		print("Analyzing image: " + imgTitle);
		// Ensure image is selected
		selectImage(imgID);
		wait(WAIT_AFTER_CMD);
		if (getImageID() != imgID) {
			print("  ERROR: Failed to select Image ID " + imgID + " before processing. Aborting.");
			return;
		}
		print("  DEBUG: Image ID " + imgID + " successfully selected.");

		var success = processSingleDiameterJImage(imgID); // Call main processing function

		if (!success) {
			print("  ERROR: Processing failed for image: " + imgTitle);
		}

		// setBatchMode(false); // Optional
		print("Finished processing: " + imgTitle);
		// Do not close image in single mode
		// Do not run batch combination in single mode
	}


	// --- Final Report ---
	var T2 = getTime(); // Local var
	var TTime = (T2 - T1) / 1000; // Local var
	setForegroundColor(0, 0, 0);
	print("====================");
	print("DiameterJ Analysis Completed in: " + TTime + " Seconds");
	if (dirOutputBase != "null" && dirOutputBase != "") print("Outputs saved in: " + dirOutputBase);
	print("====================");
	// if(isOpen_DJ("Log")) selectWindow("Log"); // Commented out problematic check for now
	print("DEBUG: DiameterJ Macro finished.");
}


// ==========================================================
// User Input Dialog Function
// ==========================================================
function getDiameterJUserInput() {
	print("DEBUG: Entering getDiameterJUserInput...");
	var IJorFIJI = getVersion(); // Local var for version check

	Dialog.create("DiameterJ Options");

	// --- Orientation ---
	if (startsWith(IJorFIJI, "1.")) { // ImageJ 1.x
		Dialog.setInsets(0, 138, 0);
		Dialog.addMessage("Orientation Analysis");
		var Ana_labels = newArray("None", "OrientationJ"); // Local array
		Dialog.addChoice("Orientation Analysis:", Ana_labels, "OrientationJ");
	} else { // FIJI or ImageJ 2+
		Dialog.setInsets(0, 138, 0);
		Dialog.addMessage("Orientation Analysis");
		var Ana_labels = newArray("None", "OrientationJ", "Directionality", "Both"); // Local array
		Dialog.addChoice("Orientation Analysis:", Ana_labels, "OrientationJ");
		Dialog.addMessage("*Note: Directionality can be slow");
	}

	// --- Unit Conversion ---
	Dialog.setInsets(25, 117, 0);
	Dialog.addMessage("Automated Unit Conversion");
	var radio_items_unit = newArray("Yes", "No"); // Use distinct name
	Dialog.addRadioButtonGroup("Convert output to real units?", radio_items_unit, 1, 2, "No");
	Dialog.addNumber("Scale Bar Length (pixels):", DEFAULT_SCALE_PIXELS, 0, 7, "Pixels");
	Dialog.addNumber("Known Length (" + DEFAULT_SCALE_UNIT_NAME + "):", DEFAULT_SCALE_UNITS, 0, 7, DEFAULT_SCALE_UNIT_NAME);

	// --- Radius Location ---
	Dialog.setInsets(25, 98, 0);
	Dialog.addMessage("Identify Specific Radius Locations");
	var radio_items_radius = newArray("Yes", "No"); // Use distinct name
	Dialog.addRadioButtonGroup("Identify location of specific radii?", radio_items_radius, 1, 2, "No");
	Dialog.addNumber("Min. Fiber Radius (pixels):", DEFAULT_MIN_RADIUS_PIXELS, 0, 7, "Pixels");
	Dialog.addNumber("Max. Fiber Radius (pixels):", DEFAULT_MAX_RADIUS_PIXELS, 0, 7, "Pixels");

	// --- Batch Processing ---
	Dialog.setInsets(25, 142, 0);
	Dialog.addMessage("Batch Processing");
	var radio_items_batch = newArray("Yes", "No"); // Use distinct name
	Dialog.addRadioButtonGroup("Analyze multiple images?", radio_items_batch, 1, 2, "Yes");
	Dialog.addRadioButtonGroup("Combine batch results?", radio_items_batch, 1, 2, "Yes"); // Combo uses same Yes/No

	// --- Show Dialog (Fragile Workaround - Assume OK) ---
	print("DEBUG: About to call Dialog.show (ignoring return value)...");
	Dialog.show;
	print("DEBUG: Dialog.show executed. Retrieving values...");

	// --- Retrieve Values (Assign to Globals) ---
	// Must retrieve in the exact order items were added to the dialog
	choice_orien = Dialog.getChoice();

	unit_conv = Dialog.getRadioButton();
	unit_pix = Dialog.getNumber();
	unit_real = Dialog.getNumber();

	R_Loc = Dialog.getRadioButton();
	lowT = Dialog.getNumber(); // Min Radius
	highT = Dialog.getNumber(); // Max Radius

	Batch_analysis = Dialog.getRadioButton();
	batch_combo = Dialog.getRadioButton();
	print("DEBUG: Retrieved all dialog values (assuming OK).");

	// --- Set Unit String ---
	if (unit_conv == "Yes") {
		unit_meas_string = DEFAULT_SCALE_UNIT_NAME; // Use the default or get from dialog if added
		// Basic validation for scale bar values
		if (unit_pix <= 0 || unit_real <= 0) {
			exit("Scale bar pixel length and known length must be positive values for conversion.");
		}
	} else {
		unit_meas_string = "pixels"; // Use pixels if no conversion
		// Reset scale values if not converting, to avoid accidental use
		unit_pix = 0;
		unit_real = 0;
	}
	print("DEBUG: Unit conversion: " + unit_conv + ", Scale: " + unit_pix + " pixels = " + unit_real + " " + unit_meas_string);

	// --- Validate Radius Location thresholds ---
	if (R_Loc == "Yes") {
		if (lowT < 0 || highT < lowT || highT > 255) { // Basic checks
			exit("Invalid Min/Max Fiber Radius values for location identification.");
		}
	}
	print("DEBUG: Radius Location: " + R_Loc + ", Min=" + lowT + ", Max=" + highT);


	print("DEBUG: getDiameterJUserInput finished successfully.");
	return true; // Assume success because we can't reliably detect cancel
}

// ==========================================================
// Core Image Processing Function (for one DiameterJ image)
// ==========================================================
function processSingleDiameterJImage(imgID) {
	// Uses globals: unit_conv, unit_pix, unit_real, unit_meas_string, R_Loc, lowT, highT, choice_orien, dirOutputBase

	print("  DEBUG [ProcDJ]: Starting processing for ID: " + imgID);
	selectImage(imgID); // Ensure active
	var name0 = getTitle(); // Original title (might have -1 etc)
	var baseName = removeExtension(name0); // Base name for outputs
	print("  DEBUG [ProcDJ]: Base name: " + baseName);

	// --- Create Output Directories ---
	// Uses global dirOutputBase
	var myDir = dirOutputBase + "Diameter Analysis Images" + File.separator;
	var myDir1 = dirOutputBase + "Summaries" + File.separator;
	var myDir2 = dirOutputBase + "Histograms" + File.separator;
	var myDir4 = dirOutputBase + "Diameter Location" + File.separator; // For Radius Location feature
	File.makeDirectory(myDir);
	File.makeDirectory(myDir1);
	File.makeDirectory(myDir2);
	if (R_Loc == "Yes") File.makeDirectory(myDir4); // Only if needed
	// Add check for directory creation failure?
	if (!File.exists(myDir) || !File.exists(myDir1) || !File.exists(myDir2)) {
		print("  ERROR [ProcDJ]: Failed to create required output subdirectories in " + dirOutputBase);
		return false; // Indicate failure
	}
	print("  DEBUG [ProcDJ]: Output directories created/ensured.");

	// --- Define Output Paths ---
	// Use local path variables constructed from baseName
	var path0 = myDir + baseName; // Base for some image outputs? Unused in original?
	var path1 = myDir2 + baseName + "_BranchInfo.csv"; // Branch Info (Char Lengths)
	var path2 = myDir + baseName + "_Skeleton.tif"; // Skeleton image
	// path3 - path4 unused?
	var path5 = myDir1 + baseName + "_Total_Summary.csv"; // Final Summary
	var path6 = myDir2 + baseName + "_Diameter_HistogramPlot.tif"; // Saved plot image
	// path7 unused?
	var path8 = myDir2 + baseName + "_Diameter_HistogramData.csv"; // Raw Histo Data
	var path9 = myDir + baseName + "_Pore_Outlines.tif"; // Pore outlines image
	// path10 unused?
	var path11 = myDir2 + baseName + "_Pore_Data.csv"; // Pore particle analysis results
	// path12 unused?
	var path13 = myDir2 + baseName + "_DistanceMap_XYCoords.txt"; // EDT coords - intermediate?
	var path14 = myDir + baseName + "_EDT_Overlay.tif"; // EDT with centerline overlay
	// path15 unused?
	var path16 = myDir2 + baseName + "_Intersections.csv"; // Combined branch info? Matches original p16
	// path17 unused in path list, used for OrientJ image
	var path18 = myDir + baseName + "_Processing_Montage.png"; // Final montage
	var path19 = myDir4 + baseName + "_EDT_ForRadiusLocation.tif"; // Saved EDT if R_Loc=Yes
	var path20 = myDir4 + baseName + "_Radius_LocationOverlay.tif"; // Final overlay if R_Loc=Yes
	var path21 = myDir2 + baseName + "_OrientJ_HistData.csv"; // OrientJ Histo Data
	var path22 = myDir2 + baseName + "_Directionality_HistData.csv"; // Directionality Histo Data

	// --- Prepare Image (Convert non-TIFF to TIFF if needed, Ensure Binary) ---
	print("  DEBUG [ProcDJ]: Preparing image...");
	var currentImgID = imgID; // Keep track of potentially changing ID
	var currentTitle = name0;
	var inputIsBinary = false;
	var tempTiffPath = ""; // Path if we create a temp TIFF

	if (!(endsWith(toLowerCase(currentTitle), ".tif") || endsWith(toLowerCase(currentTitle), ".tiff"))) {
		print("  INFO [ProcDJ]: Input is not TIFF, converting to binary TIFF...");
		run("Make Binary"); // Ensure binary
		// Invert if necessary (assume white features on black background desired)
		setAutoThreshold("Default dark"); // Use standard default threshold
		run("Threshold..."); // Open threshold window to check
		waitForUser("Check Threshold", "Ensure fibers are WHITE (255) and background BLACK (0).\nAdjust threshold sliders if needed, then click Apply, then OK.");
		run("Convert to Mask"); // Apply threshold to make binary
		// Check inversion (want fibers=0 for analysis like skeletonize)
		getStatistics(area, mean); // Need mean measurement enabled
		if (mean > 128) run("Invert"); // Invert if fibers are white

		tempTiffPath = myDir + baseName + "_tempInput.tif"; // Save in Analysis Images dir
		saveAs("Tiff", tempTiffPath);
		closeImage_DJ(currentImgID); // Close original non-tiff
		currentImgID = openImageAndGetID_DJ(tempTiffPath); // Open the new TIFF
		if (currentImgID == 0) { print("  ERROR [ProcDJ]: Failed to reopen temporary TIFF."); return false; }
		selectImage(currentImgID); wait(WAIT_AFTER_CMD); // Select it
		if (getImageID() != currentImgID) { print("  ERROR [ProcDJ]: Failed to select temporary TIFF."); closeImage_DJ(currentImgID); return false; }
		currentTitle = getTitle(); // Update title
		inputIsBinary = true; // Mark as binary now
		print("  DEBUG [ProcDJ]: Converted to temporary binary TIFF: ID=" + currentImgID + ", Title=" + currentTitle);
	} else {
		// Input is TIFF, check if it's binary
		if (is("binary")) {
			print("  INFO [ProcDJ]: Input is already binary.");
			// Check inversion (want fibers=0 for analysis)
			getStatistics(area, mean);
			if (mean > 128) {
				print("  INFO [ProcDJ]: Inverting binary image (white fibers detected).");
				run("Invert");
			} else {
				print("  INFO [ProcDJ]: Binary image has black fibers (mean<=128). Good.");
			}
			inputIsBinary = true;
		} else {
			print("  WARNING [ProcDJ]: Input TIFF is not binary. Attempting thresholding...");
			run("Make Binary"); // Try simple make binary first
			setAutoThreshold("Default dark");
			run("Threshold...");
			waitForUser("Check Threshold", "Ensure fibers are WHITE (255) and background BLACK (0).\nAdjust threshold sliders if needed, then click Apply, then OK.");
			run("Convert to Mask");
			getStatistics(area, mean);
			if (mean > 128) run("Invert");
			inputIsBinary = true; // Assume it's binary after this
			print("  DEBUG [ProcDJ]: Thresholded TIFF. Active ID: " + currentImgID);

		}
	}
	if (!inputIsBinary) { print("ERROR [ProcDJ]: Could not ensure input image is binary."); return false; }
	// We should now have a binary image with black fibers (0) on white background (255) in window currentImgID

	// --- Set Scale ---
	print("  DEBUG [ProcDJ]: Setting scale...");
	run("Set Scale...", "distance=" + unit_pix + " known=" + unit_real + " pixel=1 unit=[" + unit_meas_string + "]");
	setOption("BlackBackground", false); // Important for many plugins

	// --- Initial Area Measurement ---
	getHistogram(values, counts, 256); // values/counts are local
	var fiber_area = counts[0]; // Pixels with value 0 (fibers)
	var background_area = counts[255]; // Pixels with value 255 (background)
	var total_area = fiber_area + background_area;
	print("  DEBUG [ProcDJ]: Fiber area (black pixels): " + fiber_area);
	if (fiber_area == 0) { print("  ERROR [ProcDJ]: No fibers (black pixels) found in binary image " + currentTitle); return false; }


	// --- Skeletonize ---
	print("  DEBUG [ProcDJ]: Skeletonizing...");
	var skelID = duplicateImage_DJ(currentImgID, baseName + "_Skel_Processing"); // Duplicate first
	if (skelID == 0) { print("  ERROR [ProcDJ]: Failed to duplicate for Skeletonization."); return false; }
	selectImage(skelID); wait(WAIT_AFTER_CMD); // Select duplicate
	if (getImageID() != skelID) { print("  ERROR [ProcDJ]: Failed to select skeleton duplicate."); closeImage_DJ(skelID); return false; }
	run("Skeletonize");
	run("Make Binary"); // Ensure skeleton is binary (might not be needed)
	// Invert skeleton? Analyze Skeleton usually wants white skeleton on black. Let's test.
	// getStatistics(area, mean); if (mean < 128) run("Invert"); // Invert if skeleton is black
	saveAs("Tiff", path2); // Save skeleton image
	print("  DEBUG [ProcDJ]: Skeleton saved to: " + path2);


	// --- Analyze Skeleton ---
	print("  DEBUG [ProcDJ]: Analyzing Skeleton...");
	selectImage(skelID); wait(WAIT_AFTER_CMD); // Select skeleton again
	if (getImageID() != skelID) { print("  ERROR [ProcDJ]: Failed to select skeleton for analysis."); closeImage_DJ(skelID); return false; }
	// Ensure Analyze Skeleton is measuring length
	run("Set Measurements...", "mean standard modal min max display redirect=None decimal=3"); // Ensure defaults + display label are on
	run("Analyze Skeleton (2D/3D)", "prune=[shortest branch] show"); // Run analysis, show results table and labeled image
	wait(WAIT_AFTER_CMD * 2); // Wait longer after analysis

	// --- Process Results Table (Branch information) ---
	var mthree_point = 0; // Initialize metrics
	var mfour_point = 0;
	var char_Length_Mean = 0;
	var char_Length_SD = 0;
	var char_Length_Max = 0;
	var mfiber_length_total = 0; // Sum of all branches from table

	if (isOpen("Branch information")) { // Check if results table appeared
		print("  DEBUG [ProcDJ]: Processing 'Branch information' table...");
		selectWindow("Branch information");
		saveAs("Results", path1); // Save branch info CSV
		for (var r = 0; r < nResults; r++) { mfiber_length_total += getResult("Branch length", r); }

		print("  DEBUG [ProcDJ]: Total branch length from table: " + mfiber_length_total);
		// Get junction counts - these might be in a separate summary or from direct results
		// The original script gets these AFTER closing results, which is wrong.
		// Let's try getting them from the table if possible, or use fallback.
		// Analyze Skeleton results vary; need to see table headers. Assuming standard output for now.
		// For now, using placeholder values - **NEEDS VERIFICATION based on actual Analyze Skeleton output**
		// mthree_point = getResultCountWhere("V1.Type == 'JUNCTION' && V2.Type == 'JUNCTION' && V3.Type == 'JUNCTION'"); // Example pseudo-code
		// mfour_point = getResultCountWhere("V1.Type == 'JUNCTION' && V2.Type == 'JUNCTION' && V3.Type == 'JUNCTION' && V4.Type == 'JUNCTION'");
		print("  WARNING [ProcDJ]: Junction counts (mthree_point, mfour_point) need specific logic based on Analyze Skeleton output table format - using 0 for now.");

		// Summarize Branch Lengths
		run("Summarize"); // Summarize the Branch Info table
		wait(WAIT_AFTER_CMD);
		if (isOpen("Summary of Branch information")) { // Check summary window exists
			selectWindow("Summary of Branch information");
			char_Length_Mean = getResult("Mean", indexOf(getResult("Column"), "Branch length"));
			char_Length_SD = getResult("StdDev", indexOf(getResult("Column"), "Branch length"));
			char_Length_Max = getResult("Max", indexOf(getResult("Column"), "Branch length"));
			print("  DEBUG [ProcDJ]: Branch Length Stats: Mean=" + char_Length_Mean + ", SD=" + char_Length_SD + ", Max=" + char_Length_Max);
			saveAs("Text", path1 + ".summary.txt"); // Save summary text
			close(); // Close summary window
		} else { print("  WARNING [ProcDJ]: Could not find Summary window for Branch information."); }

		selectWindow("Branch information"); close(); // Close Branch Info table
		// Also close the labeled skeleton image window if it exists
		var labeledSkelTitle = "Labelled Skeleton of " + getTitleFromPath(path2);
		if (isOpen_DJ(labeledSkelTitle)) { selectWindow(labeledSkelTitle); close(); }

	} else {
		print("  ERROR [ProcDJ]: 'Branch information' results table not found after Analyze Skeleton.");
		// Cannot calculate metrics that depend on this table
	}

	// --- Calculate Corrected Lengths/Diameters (using table sum if available) ---
	// This calculation relies heavily on junction counts which we couldn't reliably get yet.
	// Using placeholders for now. **NEEDS REVISION BASED ON JUNCTION COUNT METHOD**
	var CMedial_Len = mfiber_length_total; // Start with table sum
	var CVfiber_Length = mfiber_length_total; // Use same for Voronoi estimate for now
	var CMFiber_Diam = 0;
	var CVfiber_Diam = 0;
	var V_M_Mean = 0;

	if (mfiber_length_total > 0 && mthree_point >= 0 && mfour_point >= 0) { // Only if we have length and junction counts
		var c = fiber_area / mfiber_length_total; // Initial diameter estimate
		var d; // Previous estimate for loop
		var iter = 0; var maxIter = 20; // Iterative correction loop
		do {
			d = c;
			CMedial_Len = mfiber_length_total - mthree_point * 0.5 * c - mfour_point * c;
			if (CMedial_Len <= 0) { print("  WARNING [ProcDJ]: Corrected medial length became non-positive during iteration."); CMedial_Len = mfiber_length_total; break; } // Prevent division by zero/negative
			c = fiber_area / CMedial_Len;
			iter++;
		} while (abs(c - d) >= 0.001 && iter < maxIter); // Check absolute difference
		if (iter == maxIter) print("  WARNING [ProcDJ]: Diameter correction loop reached max iterations.");
		CMFiber_Diam = c; // Corrected Medial Diameter

		// Apply correction to Voronoi length estimate (placeholder, original used vfiber_length from separate Voronoi step)
		// Let's just use the corrected medial length for Voronoi estimate for now
		CVfiber_Length = CMedial_Len;
		if (CVfiber_Length > 0) {
			CVfiber_Diam = fiber_area / CVfiber_Length;
		} else { CVfiber_Diam = 0; }

		V_M_Mean = (CVfiber_Diam + CMFiber_Diam) / 2; // Average Diameter Estimate
		print("  DEBUG [ProcDJ]: Corrected Diams: Medial=" + CMFiber_Diam + ", VoronoiEst=" + CVfiber_Diam + ", Mean=" + V_M_Mean);
	} else {
		print("  WARNING [ProcDJ]: Skipping diameter correction (missing length or junction counts).");
	}

	closeImage_DJ(skelID); // Close the skeleton processing image


	// --- Orientation Analysis ---
	// Uses global choice_orien
	if (choice_orien == "OrientationJ" || choice_orien == "Both") {
		print("  DEBUG [ProcDJ]: Running OrientationJ...");
		var orientID = duplicateImage_DJ(currentImgID, baseName + "_OrientJ_Processing"); // Use original binary image
		if (orientID != 0) {
			selectImage(orientID); wait(WAIT_AFTER_CMD);
			if (getImageID() == orientID) {
				// Need fibers to be WHITE for OrientationJ's structure tensor
				getStatistics(area, mean); if (mean < 128) run("Invert");
				run("OrientationJ Distribution", "log=0.0 tensor=9.0 gradient=0 min-coherency=5.0 min-energy=0.0 s-distribution=on hue=Gradient-X sat=Gradient-X bri=Gradient-X ");
				wait(WAIT_AFTER_CMD * 2); // Wait for analysis and plot

				// Save Orientation Map Image? Original didn't save this with a path variable.
				// Let's assume the active image is the map.
				var mapTitle = getTitle();
				if (mapTitle != getTitleFromPath(orientID + "")) { // Check if title changed
					saveAs("Tiff", myDir + baseName + "_OrientationMap.tif");
				}

				// Save Plot Data
				if (isOpen("Orientation Distribution")) {
					selectWindow("Orientation Distribution"); // Select the plot window
					Plot.getValues(xAngles, yFrequencies); // Get data from plot
					// Save to results table
					run("Clear Results"); // Clear previous results
					for (var ia = 0; ia < xAngles.length; ia++) {
						setResult("Angle", ia, xAngles[ia]);
						setResult("Frequency", ia, yFrequencies[ia]);
					}
					updateResults(); // Show table
					saveAs("Results", path21); // Save OrientJ histogram data
					if (isOpen("Results")) { selectWindow("Results"); run("Close"); } // Close results table
					selectWindow("Orientation Distribution"); close(); // Close plot
				} else { print("  WARNING [ProcDJ]: OrientationJ plot window not found."); }

			} else { print("  ERROR [ProcDJ]: Failed to select image for OrientationJ."); }
			closeImage_DJ(orientID); // Close OrientJ processing duplicate
		} else { print("  ERROR [ProcDJ]: Failed to duplicate image for OrientationJ."); }
	}
	if (choice_orien == "Directionality" || choice_orien == "Both") {
		print("  DEBUG [ProcDJ]: Running Directionality (may be slow)...");
		var directID = duplicateImage_DJ(currentImgID, baseName + "_Directionality_Processing");
		if (directID != 0) {
			selectImage(directID); wait(WAIT_AFTER_CMD);
			if (getImageID() == directID) {
				// Directionality usually wants white features? Check documentation. Assume yes for now.
				getStatistics(area, mean); if (mean < 128) run("Invert");
				run("Directionality", "method=[Fourier components] nbins=180 histogram=-90 display_table");
				wait(WAIT_AFTER_CMD * 2);

				// Save Histogram Data - window title is complex
				var dirHistTitle = "Directionality histograms for " + baseName + "_Directionality_Processing (using Fourier components)"; // Construct expected title
				if (isOpen_DJ(dirHistTitle)) {
					selectWindow(dirHistTitle);
					saveAs("Results", path22); // Save Directionality histogram data
					close();
				} else {
					// Try finding window by partial match?
					var titles = getList("image.titles"); var found = false;
					for (var t = 0; t < titles.length; t++) {
						if (startsWith(titles[t], "Directionality histograms for")) {
							selectWindow(titles[t]); saveAs("Results", path22); close(); found = true; break;
						}
					}
					if (!found) print("  WARNING [ProcDJ]: Directionality histogram window not found.");
				}
				// Close other Directionality windows (table, graph) if they exist
				if (isOpen_DJ("Directionality")) { selectWindow("Directionality"); run("Close"); }
				if (isOpen_DJ("Directionality Plot")) { selectWindow("Directionality Plot"); close(); }

			} else { print("  ERROR [ProcDJ]: Failed to select image for Directionality."); }
			closeImage_DJ(directID); // Close Directionality processing duplicate
		} else { print("  ERROR [ProcDJ]: Failed to duplicate image for Directionality."); }
	}


	// --- Distance Map Analysis (EDT for Diameter Histogram) ---
	print("  DEBUG [ProcDJ]: Performing Distance Map analysis...");
	var edtID = duplicateImage_DJ(currentImgID, baseName + "_EDT_Processing");
	if (edtID == 0) { print("  ERROR [ProcDJ]: Failed to duplicate for Distance Map."); return false; }
	selectImage(edtID); wait(WAIT_AFTER_CMD);
	if (getImageID() != edtID) { print("  ERROR [ProcDJ]: Failed to select EDT duplicate."); closeImage_DJ(edtID); return false; }
	run("Invert"); // EDT needs white background
	run("Distance Map"); // Calculate EDT
	print("  DEBUG [ProcDJ]: EDT calculated.");

	// --- Get Histogram from Skeleton Region of EDT ---
	// Need the skeleton image again (path2)
	if (!File.exists(path2)) { print("  ERROR [ProcDJ]: Skeleton file not found (" + path2 + ") for EDT histogram."); closeImage_DJ(edtID); return false; }
	open(path2); // Open the saved skeleton
	var skelHistoID = getImageID();
	if (skelHistoID == 0) { print("  ERROR [ProcDJ]: Failed to open skeleton file for EDT histogram."); closeImage_DJ(edtID); return false; }
	run("Create Selection"); // Create selection from skeleton pixels
	closeImage_DJ(skelHistoID); // Close skeleton image now that selection is made
	selectImage(edtID); // Switch back to EDT image
	// Selection should still be active
	run("Histogram"); // Get histogram of EDT values ONLY under the skeleton selection
	wait(WAIT_AFTER_CMD);

	var radiusValues = newArray(0); // Initialize as empty arrays
	var frequencyCounts = newArray(0);
	var area_mode = 0, area_median = 0, area_min = 0, area_max = 0, area_skew = 0, area_kurt = 0;
	var area_ave = 0, area_stdev = 0; // Gaussian fit results

	if (isOpen("Histogram of " + baseName + "_EDT_Processing")) { // Check if Histogram window opened
		selectWindow("Histogram of " + baseName + "_EDT_Processing");
		Plot.getValues(radiusValues, frequencyCounts); // Get histogram data (Radius = EDT value)
		saveAs("Text", path8 + ".raw_plot.txt"); // Save raw plot data text
		// Save plot image?
		saveAs("Tiff", path6);

		// Get stats from the Plot window's results table if possible
		// Might need to run "List" from plot window first? Or get from array stats.
		// Let's calculate from arrays for robustness.
		var stats = calculateBasicStats(radiusValues, frequencyCounts);
		area_median = 2 * stats[0]; // Multiply by 2 for diameter
		area_min = 2 * stats[1];
		area_max = 2 * stats[2];
		print("  DEBUG [ProcDJ]: Histo Stats (Median, Min, Max Diam): " + area_median + ", " + area_min + ", " + area_max);

		// Fit Gaussian (optional, can be slow/unreliable)
		print("  DEBUG [ProcDJ]: Fitting Gaussian to diameter histogram...");
		Fit.doFit("Gaussian", radiusValues, frequencyCounts);
		if (Fit.nEquations > 0 && !Fit.isNan()) { // Check if fit was successful
			area_ave = 2 * Fit.p(1); // Gaussian Mean * 2 = Average Diameter
			area_stdev = 2 * abs(Fit.p(2)); // Gaussian Sigma * 2 = Diameter SD (use abs value)
			print("  DEBUG [ProcDJ]: Gaussian Fit (Mean Diam, SD Diam): " + area_ave + ", " + area_stdev);
		} else { print("  WARNING [ProcDJ]: Gaussian fit failed or returned NaN."); area_ave = 0; area_stdev = 0; }

		// Skewness/Kurtosis - requires Analyze Particles or more complex calculation
		print("  WARNING [ProcDJ]: Skewness/Kurtosis calculation not implemented from raw histogram."); area_skew = 0; area_kurt = 0;
		// Mode - Find index of max frequency
		var maxFreq = 0; var modeIndex = -1;
		for (var k = 0; k < frequencyCounts.length; k++) { if (frequencyCounts[k] > maxFreq) { maxFreq = frequencyCounts[k]; modeIndex = k; } }
		if (modeIndex != -1) area_mode = 2 * radiusValues[modeIndex]; else area_mode = 0;
		print("  DEBUG [ProcDJ]: Histo Mode Diam: " + area_mode);


		close(); // Close histogram window
	} else { print("  ERROR [ProcDJ]: Histogram window not found after measuring EDT."); }

	// Save the calculated histogram data to CSV (path8)
	run("Clear Results");
	for (var j = 0; j < radiusValues.length; j++) {
		setResult("Radius_Values", j, radiusValues[j]);
		setResult("Frequency", j, frequencyCounts[j]);
	}
	updateResults();
	saveAs("Results", path8);
	if (isOpen("Results")) { selectWindow("Results"); run("Close"); }


	// --- Create EDT Overlay ---
	print("  DEBUG [ProcDJ]: Creating EDT Overlay...");
	selectImage(edtID); // Select EDT image
	wait(WAIT_AFTER_CMD);
	if (getImageID() != edtID) { print("  ERROR [ProcDJ]: Failed selection for EDT overlay."); closeImage_DJ(edtID); return false; }
	// Re-open skeleton, create selection, close skeleton (needed again)
	if (!File.exists(path2)) { print("  ERROR [ProcDJ]: Skeleton file not found (" + path2 + ") for EDT overlay."); closeImage_DJ(edtID); return false; }
	open(path2); var skelOverlayID = getImageID(); if (skelOverlayID == 0) { print("  ERROR [ProcDJ]: Failed to open skeleton file for EDT overlay."); closeImage_DJ(edtID); return false; }
	run("Create Selection"); closeImage_DJ(skelOverlayID);
	// Apply selection to EDT
	selectImage(edtID); wait(WAIT_AFTER_CMD);
	if (getImageID() != edtID) { print("  ERROR [ProcDJ]: Failed selection for EDT overlay application."); closeImage_DJ(edtID); return false; }
	// Burn skeleton onto EDT using Flatten maybe? Or Create Mask?
	// Original used Flatten which merges overlays. Let's try that.
	// Need to make skeleton selection visible (e.g., add to overlay)
	run("Add Selection...", ""); // Add current selection to overlay
	run("Flatten"); // Merge overlay with image
	saveAs("tiff", path14);
	print("  DEBUG [ProcDJ]: Saved EDT Overlay image.");
	closeImage_DJ(edtID); // Close the EDT image


	// --- Radius Location Analysis (Optional) ---
	if (R_Loc == "Yes") {
		print("  DEBUG [ProcDJ]: Performing Radius Location Analysis...");
		// Needs the EDT image again. Re-open or re-calculate? Let's re-open the saved intermediate.
		// We need to save the EDT *before* the overlay step above. Let's modify that.

		// --- MODIFICATION NEEDED: Save EDT before overlay ---
		// Go back to Distance Map Analysis section:
		// run("Distance Map");
		// print("  DEBUG [ProcDJ]: EDT calculated.");
		// ==> INSERT SAVE HERE if R_Loc == Yes <==
		// if (R_Loc == "Yes") { saveAs("Tiff", path19); print("  DEBUG [ProcDJ]: Saved intermediate EDT for Radius Location."); }
		// --- Continue with histogram section ---

		// Now, assuming path19 exists:
		if (!File.exists(path19)) { print("  ERROR [ProcDJ]: Intermediate EDT file (" + path19 + ") not found for Radius Location."); }
		else {
			open(path19); var edtLocID = getImageID();
			if (edtLocID == 0) { print("  ERROR [ProcDJ]: Failed to open intermediate EDT for Radius Location."); }
			else {
				print("  DEBUG [ProcDJ]: Applying Radius Threshold [" + lowT + " - " + highT + "]...");
				setThreshold(lowT, highT); // Use pixel thresholds from dialog
				run("Convert to Mask"); // Create mask of desired radii
				run("Create Selection"); // Select the masked pixels
				closeImage_DJ(edtLocID); // Close the EDT image

				// Overlay selection onto original image
				selectImage(currentImgID); // Select the binary input image
				wait(WAIT_AFTER_CMD);
				if (getImageID() != currentImgID) { print("  ERROR [ProcDJ]: Failed selection of original image for Radius Location overlay."); }
				else {
					run("RGB Color"); // Convert original to RGB
					roiManager("Select", roiManager("count") - 1); // Select the last added ROI (the radius mask)
					run("Add Selection...", ""); // Add to overlay (default color?)
					// Change overlay color?
					Overlay.color("red"); // Set overlay color
					run("Flatten"); // Burn overlay
					saveAs("Tiff", path20); // Save overlay image
					print("  DEBUG [ProcDJ]: Saved Radius Location overlay image.");
					// Close the RGB image if needed? Assume it replaced currentImgID.
					// No, flatten creates a new window. Close it.
					var overlayImgID = getImageID();
					if (overlayImgID != currentImgID) closeImage_DJ(overlayImgID);

				}
				roiManager("reset"); // Clean up ROI manager
			}
		}
	}


	// --- Pore Analysis ---
	print("  DEBUG [ProcDJ]: Performing Pore Analysis...");
	selectImage(currentImgID); // Start with original binary image (black fibers)
	wait(WAIT_AFTER_CMD);
	if (getImageID() != currentImgID) { print("  ERROR [ProcDJ]: Failed selection for Pore Analysis."); return false; }
	run("Set Measurements...", "area perimeter fit shape redirect=None decimal=4"); // Measurements for pores
	// Pores are the background (white = 255). Need to analyze particles on inverted image.
	// Or, threshold the background? Let's invert and analyze black pores.
	run("Duplicate...", "title=" + baseName + "_Pores_Processing");
	var poreID = getImageID();
	if (poreID == currentImgID || poreID == 0) { print("  ERROR [ProcDJ]: Failed duplicate for Pore Analysis."); return false; }
	run("Invert"); // Now pores are black (0)
	print("  DEBUG [ProcDJ]: Analyzing particles for pores...");
	// Use particle analyzer
	// Ensure results table is cleared before run
	run("Clear Results");
	run("Analyze Particles...", "size=" + PARTICLE_ANALYSIS_MIN_SIZE + "-Infinity pixel circularity=0.00-1.00 show=Outlines display exclude clear include summarize");
	wait(WAIT_AFTER_CMD);
	// Save outlines image if created
	if (isOpen(baseName + "_Pores_Processing Outlines")) { // Check for outlines window
		selectWindow(baseName + "_Pores_Processing Outlines");
		saveAs("tiff", path9); // Save pore outlines
		close();
	} else { print("  WARNING [ProcDJ]: Pore outlines image not found."); }
	// Process Results table
	var Pore_N = 0; var Mean_Pore_Size = 0; var Pore_SD = 0; var Pore_Min = 0; var Pore_Max = 0; // Init metrics
	if (isOpen("Results")) {
		selectWindow("Results");
		Pore_N = nResults; // Number of pores found
		saveAs("Results", path11); // Save pore data
		if (Pore_N > 0) {
			run("Summarize"); // Summarize the results
			wait(WAIT_AFTER_CMD);
			if (isOpen("Summary of Results")) {
				selectWindow("Summary of Results");
				// Get stats - find correct row for 'Area'
				var areaRow = -1; for (r = 0; r < nResults; r++) { if (getResult("Column", r) == "Area") areaRow = r; }
				if (areaRow != -1) {
					Mean_Pore_Size = getResult("Mean", areaRow);
					Pore_SD = getResult("StdDev", areaRow);
					Pore_Min = getResult("Min", areaRow);
					Pore_Max = getResult("Max", areaRow);
				} else { print("  WARNING [ProcDJ]: Could not find 'Area' in pore summary table."); }
				print("  DEBUG [ProcDJ]: Pore Stats: N=" + Pore_N + ", Mean=" + Mean_Pore_Size + ", SD=" + Pore_SD + ", Min=" + Pore_Min + ", Max=" + Pore_Max);
				close(); // Close Summary window
			} else { print("  WARNING [ProcDJ]: Could not find Summary window for Pore data."); }
		} else { print("  INFO [ProcDJ]: No pores found matching criteria."); }
		selectWindow("Results"); close(); // Close Results window
	} else { print("  WARNING [ProcDJ]: Results table not found after Pore Analysis."); }
	closeImage_DJ(poreID); // Close the inverted duplicate used for pore analysis


	// --- Final Calculations & Summary Table ---
	print("  DEBUG [ProcDJ]: Calculating final metrics...");
	var Percent_Porosity = background_area / total_area; // Use areas calculated earlier
	// Intersection Density & Char Length need reliable junction counts (mthree_point, mfour_point)
	// Using placeholders for Ints, Int_Den, Char_Len
	var Ints = mthree_point + mfour_point; // Total intersections (NEEDS FIXING)
	var Int_Den = (Ints / total_area) * 10000; // Density per 100x100 area (NEEDS FIXING)
	if (total_area == 0) Int_Den = 0; // Avoid division by zero
	// Use Characteristic Length from Analyze Skeleton results table (mean branch length)
	var Char_Len = char_Length_Mean; // From results table summary
	print("  WARNING [ProcDJ]: Ints, Int_Den based on placeholder junction counts. Char_Len uses Branch Length Mean.");


	// --- Create Summary Table ---
	run("Clear Results"); // Start fresh table
	// Use arrays to build table - easier to manage
	var metrics = newArray(
		"Avg Diameter (V_M_Mean)", // From correction loop (needs junction fix)
		"Diameter Histo Mean (Gaussian Fit)",
		"Diameter Histo SD (Gaussian Fit)",
		"Diameter Histo Mode",
		"Diameter Histo Median",
		"Diameter Histo Min",
		"Diameter Histo Max",
		"Diameter Histo Skewness", // Not calculated yet
		"Diameter Histo Kurtosis", // Not calculated yet
		"Fiber Area (" + unit_meas_string + "^2)", // Fiber pixels * scale^2
		"Total Fiber Length (Skel Branches, " + unit_meas_string + ")", // Sum from table
		"Mean Pore Area (" + unit_meas_string + "^2)",
		"Pore Area SD (" + unit_meas_string + "^2)",
		"Min Pore Area (" + unit_meas_string + "^2)",
		"Max Pore Area (" + unit_meas_string + "^2)",
		"Percent Porosity (%)",
		"Number of Pores",
		"Number of Intersections", // Placeholder
		"Intersection Density (N / 10000 " + unit_meas_string + "^2)", // Placeholder
		"Char. Length (Mean Branch, " + unit_meas_string + ")", // From table
		"Char. Length SD (Branch, " + unit_meas_string + ")", // From table
		"Max Branch Length (" + unit_meas_string + ")" // From table
	);
	var values = newArray(
		V_M_Mean, // Needs reliable calculation
		area_ave,
		area_stdev,
		area_mode,
		area_median,
		area_min,
		area_max,
		area_skew, // Placeholder
		area_kurt, // Placeholder
		fiber_area * (unit_real / unit_pix) * (unit_real / unit_pix), // Apply scale^2
		mfiber_length_total, // Already scaled if scale was set before Analyze Skeleton
		Mean_Pore_Size, // Already scaled if scale was set before Analyze Particles
		Pore_SD, // Scaled
		Pore_Min, // Scaled
		Pore_Max, // Scaled
		Percent_Porosity * 100, // Convert fraction to percent
		Pore_N,
		Ints, // Placeholder
		Int_Den * (unit_real / unit_pix) * (unit_real / unit_pix) * 10000, // Adjust scale for density unit (NEEDS FIXING)
		Char_Len, // Scaled
		char_Length_SD, // Scaled
		char_Length_Max // Scaled
	);

	// Populate results table
	for (var k = 0; k < metrics.length; k++) {
		setResult("Metric", k, metrics[k]);
		// Format numbers nicely? Optional. Use d2s(number, digits)
		setResult("Value", k, values[k]);
	}
	updateResults();
	saveAs("Results", path5); // Save Total Summary CSV
	if (isOpen("Results")) { selectWindow("Results"); run("Close"); }


	// --- Create Processing Montage ---
	print("  DEBUG [ProcDJ]: Creating Processing Montage...");
	createDiameterJMontage(currentImgID, path2, path14, path9, path18); // Pass IDs/Paths


	// --- Final Cleanup for this image ---
	// Delete intermediate files? path13 (EDT coords)
	if (File.exists(path13)) File.delete(path13);
	// Delete temporary TIFF if created
	if (tempTiffPath != "" && File.exists(tempTiffPath)) {
		File.delete(tempTiffPath);
	}
	// Delete intermediate saved skeleton (path2)? Optional, maybe keep.
	// Delete EDT overlay (path14)? Optional.
	// Delete pore outlines (path9)? Optional.

	return true; // Indicate success for this image
} // End processSingleDiameterJImage


// ==========================================================
// Helper Function to create DiameterJ Montage
// ==========================================================
function createDiameterJMontage(origID, skelPath, edtOverlayPath, poreOutlinesPath, montageSavePath) {
	print("    DEBUG [MontageDJ]: Creating montage...");
	var idsToMontage = newArray();
	var titlesToMontage = "";
	var ok = true;

	// 1. Original (Inverted? Needs black background)
	selectImage(origID); wait(WAIT_AFTER_CMD);
	if (getImageID() == origID) {
		var montOrigID = duplicateImage_DJ(origID, getTitle() + "_Mont1");
		if (montOrigID != 0) {
			selectImage(montOrigID); run("Invert"); // Invert for montage view
			idsToMontage = Array.concat(idsToMontage, montOrigID);
			titlesToMontage += getTitle() + " ";
		} else ok = false;
	} else ok = false;

	// 2. Skeleton
	if (ok && File.exists(skelPath)) {
		var montSkelID = openImageAndGetID_DJ(skelPath);
		if (montSkelID != 0) {
			idsToMontage = Array.concat(idsToMontage, montSkelID);
			selectImage(montSkelID); titlesToMontage += getTitle() + " "; // Add title after select
		} else ok = false;
	} else ok = false;

	// 3. EDT Overlay
	if (ok && File.exists(edtOverlayPath)) {
		var montEdtID = openImageAndGetID_DJ(edtOverlayPath);
		if (montEdtID != 0) {
			idsToMontage = Array.concat(idsToMontage, montEdtID);
			selectImage(montEdtID); titlesToMontage += getTitle() + " ";
		} else ok = false;
	} else ok = false;

	// 4. Pore Outlines
	if (ok && File.exists(poreOutlinesPath)) {
		var montPoreID = openImageAndGetID_DJ(poreOutlinesPath);
		if (montPoreID != 0) {
			idsToMontage = Array.concat(idsToMontage, montPoreID);
			selectImage(montPoreID); titlesToMontage += getTitle() + " ";
		} else ok = false;
	} else {
		// If pore file doesn't exist, maybe add a blank image placeholder? Or skip.
		print("    INFO [MontageDJ]: Pore outlines file not found, montage will have fewer images.");
	}

	// --- Create Stack & Montage ---
	if (idsToMontage.length >= 2) { // Need at least 2 images
		titlesToMontage = trim(titlesToMontage);
		print("    DEBUG [MontageDJ]: Creating stack for montage from titles: [" + titlesToMontage + "]");
		run("Images to Stack", "titles=[" + titlesToMontage + "] use");
		wait(WAIT_AFTER_CMD);
		var stackID = getImageID();
		if (stackID != 0) {
			print("    DEBUG [MontageDJ]: Creating montage visualization...");
			selectImage(stackID); run("RGB Color");
			run("Make Montage...", "columns=2 rows=2 scale=" + MONTAGE_SCALE_DIAMJ +
				" first=1 last=" + nSlices() + " increment=1 border=" + MONTAGE_BORDER_DIAMJ +
				" font=" + MONTAGE_FONT_DIAMJ + " label use");
			wait(WAIT_AFTER_CMD);
			var montageID = getImageID();
			if (montageID != 0 && montageID != stackID) {
				saveImage(montageID, montageSavePath);
				print("    Saved montage: " + montageSavePath);
				closeImage_DJ(montageID);
			} else { print("    ERROR [MontageDJ]: Failed to create montage window."); }
			closeImage_DJ(stackID); // Close stack
		} else { print("    ERROR [MontageDJ]: Failed to create stack for montage."); }
	} else { print("    WARNING [MontageDJ]: Not enough images successfully opened (" + idsToMontage.length + ") to create montage."); }

	// --- Cleanup opened images ---
	print("    DEBUG [MontageDJ]: Cleaning up montage source images...");
	for (var i = 0; i < idsToMontage.length; i++) {
		closeImage_DJ(idsToMontage[i]);
	}
	print("    DEBUG [MontageDJ]: Finished montage creation attempt.");
}


// ==========================================================
// Batch Combination Functions (Placeholders - Need Implementation)
// ==========================================================
function runBatchCombination() {
	print("  DEBUG [BatchCombine]: Starting batch combination...");
	// Combine Radius Histograms
	combineRadiusHistograms();
	// Combine Intersection/Branch Info
	combineIntersectionData();
	// Combine Pore Area Data
	combinePoreData();
	// Combine Orientation Histograms
	combineOrientationHistograms();
	// Combine Summary Files
	combineSummaryFiles();
	print("  DEBUG [BatchCombine]: Finished batch combination functions.");
}

function combineRadiusHistograms() {
	print("    DEBUG [Combine]: Combining Radius Histograms...");
	// TODO: Implement logic similar to original script:
	// 1. Find all "*_Diameter_HistogramData.csv" files in myDir2 (Histogram dir)
	// 2. Read data from each file.
	// 3. Aggregate frequencies for each radius bin into a combined ResultsTable.
	// 4. Calculate overall Mean, SD, Skew, Kurtosis from combined data.
	// 5. Save combined table and summary stats to myDir3 (Combined Files dir).
	// 6. Delete intermediate files.
	print("    WARNING [Combine]: combineRadiusHistograms function not fully implemented yet.");
}

function combineIntersectionData() {
	print("    DEBUG [Combine]: Combining Intersection Data...");
	// TODO: Implement logic similar to original script:
	// 1. Find all "*_BranchInfo.csv" files in myDir2.
	// 2. Read 'Branch length' and 'Euclidean distance' columns from each.
	// 3. Concatenate all data into one large ResultsTable.
	// 4. Save combined table to myDir3.
	// 5. Delete intermediate files.
	print("    WARNING [Combine]: combineIntersectionData function not fully implemented yet.");
}

function combinePoreData() {
	print("    DEBUG [Combine]: Combining Pore Data...");
	// TODO: Implement logic similar to original script:
	// 1. Find all "*_Pore_Data.csv" files in myDir2.
	// 2. Read 'Area', 'Major', 'Minor' columns from each.
	// 3. Concatenate all data into one large ResultsTable.
	// 4. Save combined table to myDir3.
	// 5. Delete intermediate files.
	print("    WARNING [Combine]: combinePoreData function not fully implemented yet.");
}

function combineOrientationHistograms() {
	print("    DEBUG [Combine]: Combining Orientation Histograms...");
	// TODO: Implement logic similar to original script:
	// 1. Find all "*_OrientJ_HistData.csv" OR "*_Directionality_HistData.csv" files in myDir2.
	// 2. Read Angle and Frequency data.
	// 3. Aggregate frequencies for each angle bin into a combined ResultsTable.
	// 4. Save combined table to myDir3.
	// 5. Delete intermediate files.
	print("    WARNING [Combine]: combineOrientationHistograms function not fully implemented yet.");
}

function combineSummaryFiles() {
	print("    DEBUG [Combine]: Combining Summary Files...");
	// TODO: Implement logic similar to original script:
	// 1. Find all "*_Total_Summary.csv" files in myDir1 (Summaries dir).
	// 2. Read Metric and Value columns from each.
	// 3. Create a combined ResultsTable where each column represents a file and rows are metrics.
	// 4. Save combined table to myDir3.
	// 5. Delete intermediate files.
	print("    WARNING [Combine]: combineSummaryFiles function not fully implemented yet.");
}


// ==========================================================
// Utility Functions (Specific versions for this script)
// ==========================================================

// --- Check if file is a supported image type ---
function isSupportedImageFile(lowerCasePath) {
	return endsWith(lowerCasePath, ".tif") || endsWith(lowerCasePath, ".tiff") ||
		endsWith(lowerCasePath, ".jpg") || endsWith(lowerCasePath, ".jpeg") ||
		endsWith(lowerCasePath, ".gif") || endsWith(lowerCasePath, ".bmp") ||
		endsWith(lowerCasePath, ".png");
}

// --- Open Image (using select by title strategy) ---
function openImageAndGetID_DJ(path) { // Added _DJ suffix
	print("  DEBUG [Util]: Opening path: " + path);
	var expectedTitle = getTitleFromPath_DJ(path);
	var forwardSlashPath = replace(path, "\\", "/");
	print("  DEBUG [Util]: Using forward slashes: " + forwardSlashPath + ", expecting title: " + expectedTitle);

	open(forwardSlashPath);
	wait(WAIT_AFTER_OPEN); // Use configured wait

	var id = 0; var titleFound = "";
	if (isOpen_DJ(expectedTitle)) { titleFound = expectedTitle; }
	else { var altTitle = expectedTitle + "-1"; if (isOpen_DJ(altTitle)) { titleFound = altTitle; print("  DEBUG [Util]: Found window with alternate title: " + titleFound); } }

	if (titleFound != "") {
		print("  DEBUG [Util]: Window '" + titleFound + "' found. Selecting...");
		selectWindow(titleFound); wait(WAIT_AFTER_CMD); id = getImageID();
		if (id != 0) { print("  DEBUG [Util]: Got ID " + id + " after selecting '" + titleFound + "'."); }
		else { print("  ERROR [Util]: Selected '" + titleFound + "' but failed to get valid ID (got 0)."); }
	} else { print("  ERROR [Util]: Window with title '" + expectedTitle + "' (or '-1') not found after open."); }

	print("  DEBUG [Util]: openImageAndGetID_DJ returning ID: " + id);
	return id;
}

// --- Duplicate Image (using select strategy) ---
function duplicateImage_DJ(sourceID, newTitle) { // Added _DJ suffix
	print("  DEBUG [Util]: Duplicating from source ID " + sourceID + " to title '" + newTitle + "'");
	// 1. Select source
	selectImage(sourceID); wait(WAIT_AFTER_CMD);
	// 2. Verify selection
	var activeID = getImageID(); var activeTitle = getTitle();
	if (activeID != sourceID) { print("  ERROR [Util]: Failed select source ID " + sourceID + ". Active=" + activeID + ". Cannot duplicate."); return 0; }
	print("  DEBUG [Util]: Selected source: ID=" + sourceID + ", Title='" + activeTitle + "'");
	// 3. Duplicate
	run("Duplicate...", "title=[" + newTitle + "]"); wait(WAIT_AFTER_OPEN); // Longer wait after duplicate
	// 4. Get ID of new window
	var dupID = getImageID(); var dupTitle = getTitle();
	// 5. Validate
	if (dupID == sourceID || dupID == 0) { print("  ERROR [Util]: Duplicate command failed or returned invalid ID. dupID=" + dupID); return 0; }
	else if (dupTitle != newTitle && dupTitle != activeTitle) { print("  WARNING [Util]: Duplicate title mismatch. Expected=" + newTitle + ", Got=" + dupTitle + ", Source=" + activeTitle + ". ID=" + dupID); }
	else { print("  DEBUG [Util]: Duplicated successfully. New ID: " + dupID + ", Title: '" + dupTitle + "'"); }
	return dupID;
}

// --- Close Image Safely by ID ---
function closeImage_DJ(imgID) { // Added _DJ suffix
	if (imgID == 0) return; // Don't try to close invalid ID
	if (isOpen_DJ(imgID)) { // Use ID check version if possible
		print("  DEBUG [Util]: Closing image ID: " + imgID);
		selectImage(imgID); // Select before closing
		run("Close");
	} else {
		print("  DEBUG [Util]: Window ID " + imgID + " already closed or invalid.");
	}
}

// --- Check if image is open by ID ---
function isOpen_DJ(idToCheck) { // Added _DJ suffix
	if (idToCheck == 0) return false;
	var ids = getList("image.ids");
	var found = false;
	for (var i = 0; i < ids.length; i++) { if (parseInt(ids[i]) == idToCheck) { found = true; break; } }
	return found;
}
// --- Check if image is open by Title ---
function isOpen_DJ(title) { // Added _DJ suffix
	var list = getList("image.titles");
	var found = false;
	for (var i = 0; i < list.length; i++) { if (list[i] == title) { found = true; break; } }
	return found;
}

// --- Get title from path ---
function getTitleFromPath_DJ(path) { // Added _DJ suffix
	var sep = File.separator; var lastSep = lastIndexOf(path, sep);
	if (lastSep < 0) lastSep = lastIndexOf(path, "/");
	if (lastSep >= 0) { return substring(path, lastSep + 1); } else { return path; }
}

// --- Remove extension ---
function removeExtension(filename) { // Generic, reused
	var dotIndex = lastIndexOf(filename, ".");
	if (dotIndex > 0) { return substring(filename, 0, dotIndex); } else { return filename; }
}

// --- Calculate Basic Stats from Histo Arrays ---
// Returns array: [median, min, max] - simple implementations
function calculateBasicStats(valuesArr, countsArr) {
	var median = 0, min = 0, max = 0, totalCount = 0, cumulativeCount = 0;
	if (valuesArr.length == 0 || valuesArr.length != countsArr.length) return newArray(0, 0, 0);

	// Find min, max with counts > 0 and total count
	var firstValIndex = -1;
	var lastValIndex = -1;
	for (var i = 0; i < countsArr.length; i++) {
		totalCount += countsArr[i];
		if (countsArr[i] > 0) {
			if (firstValIndex == -1) firstValIndex = i; // First non-zero bin
			lastValIndex = i; // Last non-zero bin
		}
	}
	if (firstValIndex != -1) min = valuesArr[firstValIndex];
	if (lastValIndex != -1) max = valuesArr[lastValIndex];

	// Find median bin
	var medianCount = totalCount / 2.0;
	var medianIndex = -1;
	for (var i = 0; i < countsArr.length; i++) {
		cumulativeCount += countsArr[i];
		if (cumulativeCount >= medianCount) {
			medianIndex = i;
			break;
		}
	}
	if (medianIndex != -1) median = valuesArr[medianIndex];

	return newArray(median, min, max);
}

// ==========================================================
// End of Macro
// ==========================================================
