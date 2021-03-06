//=============================================================================================//
//																																																						
// ImageJ macro which measure filopodia density and length. 																																	
// single image processing version of the macro																																			
// This macro requires Enhanced Local Contrast (CLAHE.class), Skeletonize3D.jar and AnalyzeSkeleton.jar																	
//																																																							
// Created the 17.08.2016 by Guillaume Jacquemet and Alex Carisey																																					
//																																																							
// Version 1.1 - 19.05.2017																																								
//              																																																		
//=============================================================================================//

	// Precautionary measure and variable initialization

	requires("1.51a");																					// To maintain general compatibility requirements (i.e. presence of CLAHE)
	current_version_script = "v1.1";																	// The version number is saved in the log of the expriment
	number_of_tif = 0;																					// Initialization of file counter
	file_name_index = 0;																				// Initialization of index for storage

	// Verify the presence of slave plugins

	path_plugins = getDirectory("plugins");
	plugin_list = getFileList(path_plugins);
	haz_skeletonize = false;
	haz_analyzeskeleton = false;
	for (i=0;i<plugin_list.length;i++) {
	search_skeletonize = indexOf(plugin_list[i],"Skeletonize3D");
	if (search_skeletonize==0) { haz_skeletonize = true; }
	search_analyzeskeleton = indexOf(plugin_list[i],"AnalyzeSkeleton");
	if (search_analyzeskeleton==0) { haz_analyzeskeleton = true; }
}
	if(haz_skeletonize == false || haz_analyzeskeleton == false) { exit("Missing plugin!"); }

	// Directory structure of open image

 dir = getDirectory("image"); 																		//get the location of the open image
 name1=getTitle; 																					//get the name of the open image
 dotIndex = indexOf(name1, ".");																	//change the name of the open image to remove the extension
 name = substring(name1 , 0, dotIndex);																// change the name of the open image to remove the extension
	
	source_directory = getDirectory("image"); 														// Source data loading
	results_directory = getDirectory("image");														// Path for the results and various outputs
	intermediate_results_directory = results_directory+"intermediate files"+File.separator;			// Assemble string for temporary folder
	File.makeDirectory(intermediate_results_directory);												// Create temporary directory within the results location
																																																				

	// Main analysis loop, 1 iteration per tif/tiff file

	
	// Initialize variables for user satisfaction to trigger the corresponding loops and exits
	
	good_job_edge_detection = false;																					// Initialisation of user satisfaction variable for edge detection for each image
	good_job_filopodia_detection = false;																				// Initialisation of user satisfaction variable for filopodia detection for each image
	good_job_contour_detection = false;																					// Initialisation of user satisfaction variable for contour detection for each image

   a = 0;		// variable that need to be fullfil for the loop to stop
   b= 0; 		// variable that need to be fullfil for the loop to stop
   		

	main_loop = a + b  ; // main loop parameter

	
	// Open the image and make duplicates for each workflow

	while (main_loop != 2) {				// setup the main loop to allow the user to start over again

	

    interm_results_current = intermediate_results_directory+name+File.separator; 									// Concatenate the path and file name for interm_results_current
	File.makeDirectory(interm_results_current);																		// Create a directory in intermediate_results_directory
	resetMinAndMax();																								// Reset the intensity scale (to make predicatable results in case autoscale is default)
	run("8-bit");																									// Transform image into 8-bit
	// to add
	getPixelSize(unit, pixelWidth, pixelHeight);																	// Determine the unit of the image
	// to  add
	
	setTool("rectangular");																							// User Hand: draw around the cell
	waitForUser("FiloQuant: Outline the region of interest.\n Then click Ok");														// Dialog box for user to choose the cell to analyse
	run("Duplicate...", "image"); rename("image");																	// Image is duplicated and renamed image
	setTool("rectangular");																							// User hand: draw manual rectangular ROI to include representative range
	waitForUser("FiloQuant: Select ROI for best contrast\n Then click Ok");											// Dialog box for user to allow improvment of brightness/contrast
	run("Enhance Contrast", "saturated=0.35");																		// Autoscale the intensity signal according to user's ROI
	run("Select None");																								// Remove the manual drawn ROI
	run("Duplicate...", "skeleton"); rename("skeleton");															// Image is duplicated and renamed skeleton
	run("Duplicate...", "edges"); rename("edges");																	// Image is duplicated and renamed edges
	run("Duplicate...", "skeleton"); rename("merge");																// Image is duplicated and renamed merge
	

	// Edge detection loop
	
	while (good_job_edge_detection == false) {																		// Beginning of the edge detection sub-loop
		selectWindow("edges");																						// Select the copy of the original image called edges
		run("Duplicate...", "edges"); rename("edges1");																// Image is duplicated and renamed edges1
		
		// GUI for settings for edge detection
		
		Dialog.create("FiloQuant: Cell edge detection");															// GUI: create dialog box
		Dialog.addMessage("FiloQuant: Settings");																	// GUI comment
		Dialog.addNumber("Threshold for cell edge:", 6);															// Input threshold_cell_edges
		Dialog.addNumber("Number of iterations for Open:", 5);														// Input n_iterations_open
		Dialog.addNumber("Number of Cycle for Erode Dilate:", 0);													// Input n_cycles_erode_dilate
		Dialog.addCheckbox("Fill holes on edges?", true);															// Input HoleEdge
		Dialog.addCheckbox("Fill holes?", true);																	// Input HoleFill
		Dialog.addCheckbox("Input parameters to modify edge length measurement?", false);							// Input EdgeParam
		Dialog.show();																								// Display GUI
		threshold_cell_edges = Dialog.getNumber();																	// Define threshold_cell_edges
		n_iterations_open = Dialog.getNumber();																		// Define n_iterations_open
		n_cycles_erode_dilate = Dialog.getNumber();																	// Define n_cycles_erode_dilate
		HoleEdge = Dialog.getCheckbox();																			// Define HoleEdge
		HoleFill = Dialog.getCheckbox();																			// Define HoleFill
		EdgeParam = Dialog.getCheckbox();																			// Define EdgeParam
		
		selectWindow("edges1");																						// Selection of the safe copy of edges
		setThreshold(threshold_cell_edges, 255);																	// Set threshold values for edges detection
		run("Convert to Mask");																						// Transform the thresolded image into mask
		
		
		setBatchMode(false);																						// Set batch mode on (was set to default (off) before this point)
		// Perform closing of holes in the mask and at the edges of the image
		
	if (HoleEdge == true) {																									// Amazing trick to close the holes at the edge without blanking the entire image! :D
			w=getWidth(); h=getHeight();																					// Measure width and height of the image (w and h)
			w1= w+1;																										// define variable based on w to avoid bugs
			h1= h+1;																										// define variable based on h to avoid bugs
			run("Invert");																									// Turns the mask intos zeros
			run("Canvas Size...", "width="+w1+" height="+h1+" position=Top-Left");											// Reframe the image with line of 1 pixel for padding top left
			run("Invert");																									// Turns the mask back into ones																															
			run("Fill Holes");																								// Fill in the holes within the mask
			run("Canvas Size...", "width="+w+" height="+h+" position=Top-Left zero");										// Remove the added padding on top left
			run("Invert");																									// Turns the mask into zeros
			run("Canvas Size...", "width="+w1+" height="+h1+" position=Bottom-Right");										// Reframe the image with line of 1 pixel for padding bottom right
			run("Invert");																									// Turns the mask back into ones																																			
			run("Fill Holes");																								// Fill in the holes within the mask
			run("Canvas Size...", "width="+w+" height="+h+" position=Bottom-Right zero");										// Remove the added padding on bottom right
		}																																

		// Perform closing of the holes within the mask
		
		if (HoleFill == true) {																									
			run("Fill Holes");																								// |— User dependent loop to fill the holes (simpler version)
		}																																	

		// Run the commands for Open/Erode/Dilate functions
		
		run("Options...", "iterations="+n_iterations_open+" count=1 black pad do=Open");				// Run the Open command according to n_iterations_open
		run("Options...", "iterations="+n_cycles_erode_dilate+" count=1 black pad do=Erode");			// Run the Erode command according to n_cycles_erode_dilate
		run("Options...", "iterations="+n_cycles_erode_dilate+" count=1 black pad do=Dilate");			// Run the Dilate command according to n_cycles_erode_dilate
		

		// GUI for user satisfaction, if not, the while loop repeats itself
		
		setBatchMode(false);																					// Set batch mode off (was manually set to on before this point)
		selectWindow("edges1");																					// Select the image that has been modified for edge detection
		Dialog.create("Threshold");																				// GUI for user validation of the thresholding
		Dialog.addCheckbox("Is the threshold correct?", true);													// Input for user_happy_edge_check
		Dialog.show();																							// Display GUI
		user_happy_edge_check = Dialog.getCheckbox();															// Define user_happy_edge_check
		if (user_happy_edge_check) {																						//  |
			good_job_edge_detection = true;																		//  |—Switch to change the value of good_job_edge_detection when user is happy
		}																																	//  |
		else {																															//  |
			selectWindow("edges1");																				//  |—If user not happy, close edges1 and restart
			close();																														//  |
		}																																	//  |
	}																											// End of the edge detection sub-loop

	// Filopodia detection loop
	
	while (good_job_filopodia_detection == false) {																// Beginning of the filopodia detection sub-loop
		selectWindow("skeleton");																				// Select the copy of the original image called skeleton
		run("Duplicate...", "skeleton"); rename("skeleton1");													// Image is duplicated and renamed edges1
		
		// GUI for settings for filopodia detection
		
		Dialog.create("FiloQuant: Filopodia detection settings");												// GUI: create dialog box for settings for filopodia detection and threshold
		Dialog.addMessage("Filopodia detection settings");														// GUI comment
		Dialog.addNumber("Threshold for filopodia:", 25);														// Input for filopodia_threshold
		Dialog.addNumber("Filopodia minimum size:", 10);														// Input for filopodia_min_size
		Dialog.addNumber("Filopodia repair cycles:", 0);														// Input for filopodia_repair
		Dialog.addCheckbox("Use convolve to improve filopodia detection?", true);								//  Input for use_convolve
		Dialog.addCheckbox("Use local contrast enhancement to improve filopodia detection?", false); 			//  Input for use_clahe
		Dialog.addNumber("Filopodia detection: maximum distance from the cell edge?", 0);
		Dialog.show();																							// Display GUI
		filopodia_threshold = Dialog.getNumber();																// Define filopodia_threshold
		filopodia_min_size = Dialog.getNumber();																// Define filopodia_min_size
		filopodia_repair = Dialog.getNumber();																	// Define filopodia_repair
		use_convolve = Dialog.getCheckbox();																	// Define use_convolve
		use_clahe = Dialog.getCheckbox();																		// Define filopodia_threshold				
		n_distance_from_edges = Dialog.getNumber();																// Define Filopodia maximal distance from edge
		

		selectWindow("skeleton1");																				// Selection of the safe copy of skeleton		
	
		// CLAHE command if required

		if (use_clahe == true) {																				// CLAHE: improves detection of faint filopodia but must remove if image is noisy
			run("Enhance Local Contrast (CLAHE)", "blocksize=127 histogram=256 maximum=3 mask=*None*");
		}
		
		// Convolve command if required
		
		if (use_convolve == true) {																								// Convolution filter with fairly conservative kernel
			run("Convolve...", "text1=[-1 -1 -1 -1 -1\n-1 -1 -1 -1 -1\n-1 -1 24 -1 -1\n-1 -1 -1 -1 -1\n-1 -1 -1 -1 -1\n]");
		}
		run("Despeckle");																										// Remove artefacts induced by convolved
		run("Despeckle");																										// Remove artefacts induced by convolved
				
		// Drawing and identification of filopodia
		setThreshold(filopodia_threshold, 255);																					// Set threshold values for filopodia detection
				
		//setOption("BlackBackground", true);																					// Warning: system wide modification here... Not necessary??? Double check later
		run("Convert to Mask");																									// Transform the thresolded image into mask
		run("Analyze Particles...", "size=8-Infinity pixel circularity=0.00-0.80 show=Masks clear in_situ");					// Filopodia drawing 
		
		// GUI for user satisfaction, if not, the while loop repeats itself
		
		setBatchMode(false);																									// Set batch mode off (was manually set to on before this point)
		selectWindow("skeleton1");																								// Select the image that has been modified for filopodia detection
		Dialog.create("Threshold");																								// GUI for user validation of the thresholding
		Dialog.addCheckbox("Is the threshold correct?", true);																	// Input for user_happy_filopodia_check
		Dialog.show();																											// Display GUI
		user_happy_filopodia_check = Dialog.getCheckbox();																		// Define user_happy_filopodia_check
		if (user_happy_filopodia_check == true) {																					//  |
			good_job_filopodia_detection = true;																				//  |—Switch to change the value of good_job_filopodia_detection when user is happy
		}																																	//  |
		else {																															//  |
			selectWindow("skeleton1");																							//  |—If user not happy, close skeleton1 and restart
			close();																														//  |
		}																																	//  |
	}																															// End of the filopodia detection sub-loop
	
	
	// Remove filopodia too far from the edges ?
	if (n_distance_from_edges != 0) {																									// |
						
		selectWindow("edges1");	run("Duplicate...", "edges1"); rename("edges2"); 												// Egdes1 is duplicated and renamed edges2
		selectWindow("edges2"); run("Duplicate...", "edges2");	rename("edges3"); 												// Egdes2 is duplicated and renamed edges3
		selectWindow("edges2");																									// Select edges2
		run("Options...", "iterations="+n_distance_from_edges+" count=1 black pad do=Dilate");	  								 // maximal distance from edges, user input
		run("Invert");																												// Turns the mask back into ones																																				
		imageCalculator("Add create", "edges1","edges2");																		// create an image that will contain only the area that contain possible filopodia
		selectWindow("edges1"); run("Close"); 
		selectWindow("edges2"); run("Close");																					// close the unnecessary images
		selectWindow("Result of edges1"); rename("edges1");																		// Rename to have the correct name for the following analysis
			}	
			
	// Filopodia extraction
	
	imageCalculator("Subtract create", "skeleton1" , "edges1");																	// Filopodia extraction sequence
	selectWindow("Result of skeleton1"); rename("Result of skeleton");															// Select and rename the result of the image calculator
	setThreshold(80, 255);																										// Set threshold values for filopodia measurements
	run("Analyze Particles...", "size="+filopodia_min_size+"-Infinity pixel circularity=0.00-1 show=Masks clear in_situ");		// Filopodia drawing using filopodia_min_size
	run("Options...", "iterations="+filopodia_repair+" count=1 black pad do=Close");											// Filopodia repair using filopodia_repair
	run("Skeletonize (2D/3D)");																									// Run the Skeletonize (2D/3D) command (no user input, hard wired)
	run("Analyze Skeleton (2D/3D)", "prune=none show display");																	// Filopodia measurement
	selectWindow("Branch information");																							// Select the Branch information provided by the plugin used above
	IJ.renameResults("FilopodiaLength"); wait(10);																						// Rename the Branch information table as FilopodiaLength
	selectWindow("Results"); run("Close");																						// Select the Results table from the plugin and close it 
	setOption("BlackBackground", true);
	
	selectWindow("Tagged skeleton");																							// select image tagged skeleton and improve it for better filopodia validation
	run("Duplicate...", "Tagged skeleton2"); rename("Tagged skeleton2"); selectWindow("Tagged skeleton2");						// Image is duplicated, renamed Tagged skeleton2, and selected 
	run("Threshold...");
	setThreshold(3, 255);
	setOption("BlackBackground", true);
	run("Convert to Mask");																										// Image is transformed to a binary image
	run("Options...", "iterations=1 count=1 black pad do=Dilate");																// Dilate is applied to make the detected filopodia bigger
	run("8-bit");
	run("Merge Channels...", "c6=[Tagged skeleton2] c4=[merge] keep");															// Create a merged composite to inspect accuracy of extraction
		

	// GUI for user satisfaction, if not, the while loop repeats itself
		
	selectWindow("RGB");																										// Select the merged image created above
	Dialog.create("Filopodia detection");																						// GUI for user validation of the filopodia extraction
	Dialog.addCheckbox("Is the filopodia extraction correct? If not, you will restart the detection.", true);					// Input for user_happy_extraction_check
	Dialog.show();																												// Display GUI
	user_happy_extraction_check = Dialog.getCheckbox();																			// Define user_happy_extraction_check
	
	if (user_happy_extraction_check == false) {																		//  |
		selectWindow(name1); close("\\Others");
		selectWindow("FilopodiaLength"); run("Close");																			//  |—If user not happy, close everything, reset happiness variables and
		good_job_edge_detection = false;																					//  |		restart the analysis of the same image (p = p-1)
		good_job_filopodia_detection = false;																				//  |
																														//  |
	}

	else { 

	if (good_job_edge_detection == true) { a = 1 ; } else { a = 0 ;}   						// set up condition for the loop
 	if (good_job_edge_detection == true) { b = 1; } else { b = 0; }  						 // set up condition for the loop
	main_loop = a + b  ; 
	
	}
		
	}	// End of the main loop
		
	// Saving the results if the user is happy (the entire loop is skipped if the user isn't from last GUI answer)
	
		setBatchMode(true);																								// Set batch mode on (was manually set to off before this point)

		if (n_distance_from_edges != 0) {
		selectWindow("edges1"); run("Close");																			// Select the image edges1 and close it
		selectWindow("edges3");	rename("edges1");																		// Image is duplicated and renamed edges1
			   } 
		     				
		selectWindow("Result-labeled-skeletons");																		// Select the image Result-labeled-skeletons
		saveAs("Tiff",interm_results_current+name+" - Result-labeled-skeletons.tif");									// Save the image Result-labeled-skeletons with prefix of current filename
		selectWindow("RGB");																							// Select the composite RGB
		saveAs("Tiff",results_directory+name+" -Tagged skeleton RGB.tif");												// Save the image composite RGB with prefix of current filename
		selectWindow("Tagged skeleton");																				// Select the image Tagged skeleton
		saveAs("Tiff",interm_results_current+name+" -Tagged skeleton.tif");												// Save the image Tagged skeleton with prefix of current filename
		selectWindow("skeleton1");																						// Select the image skeleton1
		saveAs("Tiff",interm_results_current+name+" - skeleton.tif");													// Save the image skeleton1 with prefix of current filename
		selectWindow("edges1"); close("\\Others");																		// Close all the open windows except edges1
																									

// Allow the user to modify the contour

		if (EdgeParam == true) {																						// Allow users to modify the parameters for the contour detection
		      																											        
		while (good_job_contour_detection == false) {																	// Beginning of the contour detection sub-loop
		selectWindow("edges1");																							// Select the image edges1
		run("Duplicate...", "edges2"); rename("edges2");																// Image is duplicated and renamed edges2
		selectWindow("edges2");

// GUI for settings for contour detection
		
		Dialog.create("FiloQuant: Edge measurement settings");															// GUI: create dialog box for settings for Edges detection and measurement
		Dialog.addMessage("Edge measurement settings");																	// GUI comment
		Dialog.addNumber("Number of iterations for Close:", 4);															// Input for Edge_close
		Dialog.addNumber("Number of iterations for Erode:", 4);															// Input for Edge_erode
		Dialog.addNumber("Number of iterations for Dilate:", 4);														// Input for Edge_dilate
		Dialog.show();																									// Display GUI
		Contour_close = Dialog.getNumber();																				// Define Edge_close
		Contour_erode = Dialog.getNumber();																				// Define Edge_erode
		Contour_dilate = Dialog.getNumber();																			// Define Edge_dilate
				
		setBatchMode(true);																								// set batch mode true
		run("Duplicate...", "edges2"); rename("contour");																// Image is duplicated and renamed contour
		run("Options...", "iterations="+Contour_close+" count=1 black pad do=Close");									// Run the Close command 
		run("Options...", "iterations="+Contour_erode+" count=1 black pad do=Erode");									// Run the Erode command 
		run("Options...", "iterations="+Contour_dilate+" count=1 black pad do=Dilate");									// Run the Dilate command 
		run("Convolve...", "text1=[0	0	0	-1	-1	-1	0	0	0\n		 0	-1	-1	-3	-3	-3	-1	-1	0\n		 0	-1	-3	-3	-1	-3	-3	-1	0\n		-1	-3	-3	6	13	6	-3	-3	-1\n		-1	-3	-1	13	24	13	-1	-3	-1\n		-1	-3	-3	6	13	6	-3	-3	-1\n		 0	-1	-3	-3	-1	-3	-3	-1	0\n		 0	-1	-1	-3	-3	-3	-1	-1	0\n		 0	0	0	-1	-1	-1	0	0	0\n]"); // Run the Convolve command (no user input, hard wired)
		run("Skeletonize (2D/3D)");																						// Run the Skeletonize (2D/3D) command (no user input, hard wired)

// GUI for user satisfaction, if not, the while loop repeats itself
		
		setBatchMode(false);																							// Set batch mode off (was manually set to on before this point)
		selectWindow("contour");																						// Select the image that has been modified for contour detection
		Dialog.create("Contour detection");																				// GUI for user validation of the contour detection
		Dialog.addCheckbox("Is the contour detection correct?", true);													// Input for user_happy_contour_check
		Dialog.show();																									// Display GUI
		user_happy_contour_check = Dialog.getCheckbox();																// Define user_happy_contour_check
		
		if (user_happy_contour_check == true) {																			//  |
			good_job_contour_detection = true;																			//  |—Switch to change the value of good_job_contour_detection when user is happy
		}																																	//  |
		else {																															//  |
			selectWindow("edges1");	close("\\Others");																	//  |—If user not happy, close everything and restart
									}
									}																																	//  |
				}
				
// If the user does not want to modify the contour detection parameters, default values are used instead

	if (EdgeParam == false) {

		
		good_job_contour_detection = true;
		setBatchMode(true);																								// Set batch mode on (was manually set to off before this point)
		selectWindow("edges1");																							// Select the image edges1
		run("Duplicate...", "edges1"); rename("contour");																// Image is duplicated and renamed contour
		run("Options...", "iterations=4 count=1 black pad do=Close");													// Run the Close command 
		run("Options...", "iterations=4 count=1 black pad do=Erode");													// Run the Erode command 
		run("Options...", "iterations=4 count=1 black pad do=Dilate");													// Run the Dilate command 
		run("Convolve...", "text1=[0	0	0	-1	-1	-1	0	0	0\n		 0	-1	-1	-3	-3	-3	-1	-1	0\n		 0	-1	-3	-3	-1	-3	-3	-1	0\n		-1	-3	-3	6	13	6	-3	-3	-1\n		-1	-3	-1	13	24	13	-1	-3	-1\n		-1	-3	-3	6	13	6	-3	-3	-1\n		 0	-1	-3	-3	-1	-3	-3	-1	0\n		 0	-1	-1	-3	-3	-3	-1	-1	0\n		 0	0	0	-1	-1	-1	0	0	0\n]"); // Run the Convolve command (no user input, hard wired)
		run("Skeletonize (2D/3D)");																						// Run the Skeletonize (2D/3D) command (no user input, hard wired)
		Contour_close = 4 ;																								// Define Edge_close for setting table
		Contour_erode = 4 ;																								// Define Edge_erode for setting table
		Contour_dilate = 4 ;																							// Define Edge_dilate for setting table
			
		} // end of Edge Param false

	



		// Mesure the contour length
		setBatchMode(false);																							// Set batch mode on (was manually set to off before this point)
		selectWindow("contour");																						// Select the image that has been modified for Edges detection
		run("Analyze Skeleton (2D/3D)", "prune=none show display");														// Run the Analyze Skeleton (2D/3D) command (no user input, hard wired)
		selectWindow("Branch information");																				// Select the Branch information provided by the plugin used above
		IJ.renameResults("EdgeLength"); wait(10);																					// Rename the Branch information table as Edge information
		selectWindow("Results"); run("Close");																			// Select the Results table from the plugin and close it 
		selectWindow("contour-labeled-skeletons");																		// Select the image contour-labeled-skeletons created above
		run("8-bit");																									// Convert to 8-bit depth intensity range
		saveAs("Tiff",interm_results_current+name+" -contour.tif");														// Save the image contour-labeled-skeletons with prefix of current filename
		selectWindow("edges1");																							// Select the image edges1
		saveAs("Tiff",interm_results_current+name+" - edges.tif");														// Save the image edges1 with prefix of current filename
		run("Close All");																								// Close all the open image windows (not the tables)
	
		selectWindow("FilopodiaLength"); IJ.renameResults("Results"); wait(10);													// Rename table to Results to allow interaction
		nb_filopodia = nResults;																						// Count the number of filopodia in the current image
		for (i=0; i<nb_filopodia; i++) {																						//  |
			FilopMeas = getResult("Branch length", i);																	//  |—Save each line into FilopMeas and keep on concatenating it with itself within matrix
			FilopMeasMatrix = Array.concat(FilopMeasMatrix,FilopMeas);											//  |
		}																																	//  |
		for (i=0; i<nb_filopodia; i++) {																						//  |
			FilopMeasV1x = getResult("V1 x", i);																	//  |—Save each line into FilopMeasV1x and keep on concatenating it with itself within matrix
			FilopMeasMatrixV1x = Array.concat(FilopMeasMatrixV1x,FilopMeasV1x);											//  |
		}																																	//  |
		for (i=0; i<nb_filopodia; i++) {																						//  |
			FilopMeasV1y = getResult("V1 y", i);																	//  |—Save each line into FilopMeasV1y and keep on concatenating it with itself within matrix
			FilopMeasMatrixV1y = Array.concat(FilopMeasMatrixV1y,FilopMeasV1y);											//  |
		}																																	//  |
				
		selectWindow("Results"); IJ.renameResults("FilopodiaLength"); wait(10);													// Rename table back to FilopodiaLength to stop interaction
		selectWindow("EdgeLength"); IJ.renameResults("Results"); wait(10);														// Rename table to Results to allow interaction
		nd_edges = nResults;																							// Count the number of edges in the current image
		for (i=0; i<nd_edges; i++) {																							//  |
			EdgeMeas = getResult("Branch length", i);																	//  |—Save each line into EdgeMeas and keep on concatenating it with itself within matrix
			EdgeMeasMatrix = Array.concat(EdgeMeasMatrix,EdgeMeas);										//  |
		}																																	//  |
		selectWindow("Results"); IJ.renameResults("EdgeLength"); wait(10);														// Rename table back to EdgeLength to stop interaction
		setResult("coordinate x", 0, 0); setResult("coordinate y", 0, 0); setResult("Filopodia length "+unit, 0, 0); setResult("Edge length "+unit, 0, 0);											// Create an empty table with 4 column headers
		updateResults();																								// Haha ImageJ seems to need that to actually update the results table display
		for (i=0; i<nb_filopodia; i++) {																						//  |
			setResult("coordinate x", i, FilopMeasMatrixV1x[i+1]);														//  |—Transfer the FilopMeasMatrix into the new Results table, row by row
		}																																	//  |
		for (i=0; i<nb_filopodia; i++) {																						//  |
			setResult("coordinate y", i, FilopMeasMatrixV1y[i+1]);														//  |—Transfer the FilopMeasMatrix into the new Results table, row by row
		}	
		for (i=0; i<nb_filopodia; i++) {																						//  |
			setResult("Filopodia length "+unit, i, FilopMeasMatrix[i+1]);														//  |—Transfer the FilopMeasMatrix into the new Results table, row by row
		}			
		for (i=0; i<nd_edges; i++) {																							//  |
			setResult("Edge length "+unit, i, EdgeMeasMatrix[i+1]);															//  |—Transfer the EdgeMeasMatrix into the new Results table, row by row
		}																																	//  |
		
		FilopMeasMatrixV1y = "";																						// Cleanup of the variable 
		FilopMeasMatrixV1x = "";																						// Cleanup of the variable 
		FilopMeasMatrix = "";																							// Cleanup of the variable 
		EdgeMeasMatrix = "";																							// Cleanup of the variable 
		
		selectWindow("Results"); IJ.renameResults("FiloQuant"); wait(10);															// Rename table FiloQuant because it sounds better
		selectWindow("FiloQuant");																						// Select the FiloQuant table
		saveAs("Results", results_directory+name+" - Results.csv");														// Save the FiloQuant table with prefix of current filename
		run("Close");																									// Close the FiloQuant table
		close("FilopodiaLength"); 						// Close the FilopodiaLength table												
		close("EdgeLength");  							 // Close the FilopodiaLength table
		
		
		
	//save the settings
		setResult("Settings", 0, "Edge detection: Threshold for cell edges") ;												// Save the header for threshold value used for cell edges
		setResult("Value", 0, threshold_cell_edges) ;																		// Save the threshold value used for cell edges
		setResult("Settings", 1, "Edge detection: Number of iterations for Open") ;											// Save the header for value of open cycles used
		setResult("Value", 1, n_iterations_open) ;																			// Save the value of open cycles used
		setResult("Settings", 2, "Edge detection: Number of iterations for Erode") ;										// Save the header for value of erode cycles used
		setResult("Value", 2, n_cycles_erode_dilate) ;																		// Save the value of erode cycles used
		setResult("Settings", 3, "Edge detection: Fill holes on edges?") ;													// Save the header for use of Fill Edges command
		setResult("Value", 3, HoleEdge) ;																					// Save the header for use of Fill Edges command
		setResult("Settings", 4, "Edge detection: Fill Holes?") ;															// Save the header for use of Fill Holes command
		setResult("Value", 4, HoleFill) ;																					// Save the header for use of Fill Holes command
		setResult("Settings", 5, "Filopodia detection: Threshold for filopodia") ;											// Save the header for threshold value used for filopodia
		setResult("Value", 5, filopodia_threshold) ;																		// Save the header for threshold value used for filopodia
		setResult("Settings", 6, "Filopodia detection: Filopodia minimum size") ;											// Save the header for minimum value used for filopodia size
		setResult("Value", 6, filopodia_min_size) ;																			// Save the header for minimum value used for filopodia size
		setResult("Settings", 7, "Filopodia detection: Use convolve to improve filopodia detection?") ;						// Save the header for use of convolution for filopodia detection
		setResult("Value", 7, use_convolve) ;																				// Save the header for use of convolution for filopodia detection
		setResult("Settings", 8, "Filopodia detection: Use local contrast enhancement to improve filopodia detection?");	// Save the header for use of CLAHE
		setResult("Value", 8, use_clahe) ;																					// Save the info for use of CLAHE
		setResult("Settings", 9, "Filopodia detection: Maximal distance from edges");										// Save the header for Number of iterations for Dilate in contour detection
		setResult("Value", 9, n_distance_from_edges) ;																		// Save the value Contour_dilate
		setResult("Settings", 10, "Contour detection: Number of iterations for Close");										// Save the header for Number of iterations for Close in contour detection
		setResult("Value", 10, Contour_close) ;																				// Save the value Contour_close
		setResult("Settings", 11, "Contour detection: Number of iterations for Erode");										// Save the header for Number of iterations for Erode in contour detection
		setResult("Value", 11, Contour_erode) ;																				// Save the value Contour_erode
		setResult("Settings", 12, "Contour detection: Number of iterations for Dilate");									// Save the header for Number of iterations for Dilate in contour detection
		setResult("Value", 12, Contour_dilate) ;																			// Save the value Contour_dilate
																			
		updateResults();																									// Haha ImageJ seems to need that to actually update the results table display
		selectWindow("Results");																							// Select the Results table (the one with the settings)
		saveAs("Results", interm_results_current+name+" - settings.csv");													// Save the Settings table with prefix of current filename
		selectWindow("Results"); run("Close");																				// Close the Results window
		
																											
	
		
		
																																			
	
