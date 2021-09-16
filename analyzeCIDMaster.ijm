////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Pipeline for processing automatically acquired CID characterization data
////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Required plugins
// Image stabilizer. Source: http://www.cs.cmu.edu/~kangli/code/Image_Stabilizer.html
//
////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Input
////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Parameters & Experiment properties
chanList = newArray("488nm", "561nm");
vWeka = "3.2.34";
channelTargets = "488nm cell 561 mito";
weka_maxStackLength = 10;
weka_segThreshold = 0.7;

// Path to epxeriment directory
expDir = "";

// Paths to macros
macroPath = "";

////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Script
////////////////////////////////////////////////////////////////////////////////////////////////////////////

/*

// Validate directory structure
calibPaths = split(runMacro(macroPath+"/"+"validateRootDir.ijm",expDir+"*"+stringfromArray(chanList,"*")),"*");
alDir = calibPaths[0];
ffDir = calibPaths[1];
if (!File.isDirectory(expDir+"processed/")) {
	File.makeDirectory(expDir+"processed/");
}

// Move MM image+metadata files + rename them
runMacro(macroPath+"processMMfiles.ijm",expDir);
 
// Create timings log files for processing of ALEX image files
timingsAlPath = runMacro(macroPath+"/"+"createTimingsLog.ijm",macroPath+"*"+alDir);
timingsPath = runMacro(macroPath+"/"+"createTimingsLog.ijm",macroPath+"*"+expDir);

// Check illumination sequence for all ALEX image files
runMacro(macroPath+File.separator+"detectALEXFrameSwitch.ijm",stringfromArray(chanList," ")+"*"+timingsAlPath+"*"+expDir+"*"+expDir+"processed"+"*"+"/log_checkALEX_alignment.txt");
runMacro(macroPath+File.separator+"detectALEXFrameSwitch.ijm",stringfromArray(chanList," ")+"*"+timingsPath+"*"+expDir+"*"+expDir+"processed"+"*"+"/log_checkALEX_data.txt");

// Compute flatfielding templates
tmp = runMacro(macroPath+"computeProfile.ijm",stringfromArray(chanList," ")+"*"+expDir+"flatfielding/"+"*"+expDir+"processed/");
profiles = split(tmp," ");

print("done computing flatfielding");

// Apply flatfielding profile for all channels
if(!File.isDirectory(expDir+"processed/corrected")) {
	File.makeDirectory(expDir+"processed/corrected");
}
for (i=0;i<chanList.length;i++) {
	params = chanList[i]+"*"+profiles[i]+"*"+expDir+"processed/"+"*"+expDir+"processed/corrected/";
	runMacro(macroPath+"applyProfile.ijm",params);	
}

// Perform channel registration
alignmentP = runMacro(macroPath+"computeAlignment.ijm",stringfromArray(chanList," ")+"*"+expDir);

// Apply channel transforms
runMacro(macroPath+"applyAlignment.ijm",chanList[1]+"*"+expDir+"processed/"+"*"+alignmentP);

// Clean-up pre-processed data
params=expDir+"*"+"_ff_561nm.tif"+"*"+"_kin_";
runMacro(macroPath+"cleanup.ijm",params);

// Perform weka-based segmentation
weka_params = macroPath+"*"+vWeka+"*"+expDir+"*"+channelTargets+"*"+"_map"+"*"+weka_maxStackLength+"*"+weka_segThreshold+"*"+true;
runMacro(macroPath+"segmentation.ijm",weka_params);

*/

// Extract intensities and write results file for timelapse data
params = expDir+"*"+macroPath+"*"+"_ALEX_"+"*"+"t0_ tend_ kin_afterCID_"+"*"+"ff_488nm. ff_561nm_tf."+"*"+"cell_roi. mito_roi.";
runMacro(macroPath+"extractIntensities_timelapse.ijm",params);

// Extract intensities and write results files for single-timepoint images
//params = expDir+"*"+macroPath+"*"+"_ALEX_"+"*"+"t0_ tend_"+"*"+"ff_488nm. ff_561nm_tf."+"*"+"cell_roi. mito_roi.";
//runMacro(macroPath+"extractIntensities_stp.ijm",params);

print("pipeline finished");

////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Functions
////////////////////////////////////////////////////////////////////////////////////////////////////////////

// Convert array to string with id as delimiter
function stringfromArray(input,id) {
	out = "";
	for (i=0;i<input.length;i++) {
		out = out+id+input[i];
	}
	return out;
}