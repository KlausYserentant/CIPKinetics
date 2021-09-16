// This function obtains recording time information from metadata files and constructs results table with image files sorted by acquisition time.
//	Two possible use cases: 
//		1) Function is called to process cell data (contained in subfolders with well IDs as names)
//		2) Function is called to process alignment data (call to folder containing ALEX images from beads).
//	Input
//		[0] - macroPath
//		[1] - target path

temp = getArgument();
temp = split(temp,"*");
targetPath = temp[1];
macroPath = temp[0];
var imNames = newArray();
var imPaths = newArray();
var metaFiles = newArray();
var recTimes = newArray();
var recTimesAbs = newArray();
fs = File.separator;

setBatchMode(true);

savePath = createTimingsLog(targetPath);

setBatchMode(false);

close("Results");

return savePath;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
function createTimingsLog (rootdir) {
	// Dont parse subdirs for alignment subdir
	if (endsWith(rootdir,"alignment/")) {
		am = true;
		i = 0;
		subdirs=newArray(1);
		subdirs[0] = "";
		subdirFiles = getFileList(rootdir);
		parseImages(subdirFiles);
	}
	
	// For anything else, parse subdirs
	else {
		am = false;
		subdirs = getFileList(rootdir);
		for (i=0; i<subdirs.length; i++) {
			// wells
			print("Processing sub-dir "+subdirs[i]);
			if (endsWith(subdirs[i],"/") && (indexOf(subdirs[i],"alignment")<0) && (indexOf(subdirs[i],"flatfielding")<0)) {
				subdirFiles = getFileList(rootdir+fs+subdirs[i]);
				parseImages(subdirFiles);
			}
		}
	}

	// Create temporary arrays for sorting by acquisition time
	for (l=0;l<imNames.length;l++) {
		imNames[l] = recTimes[l]+"??"+imNames[l];
		imPaths[l] = recTimes[l]+"??"+imPaths[l];
		recTimesAbs[l] = recTimes[l]+"??"+recTimesAbs[l];
	}

	// Sort according to recording times
	Array.sort(imNames);
	Array.sort(imPaths);
	Array.sort(recTimesAbs);
	
	// Remove sorting term from sorted array entries
	for (l=0;l<imNames.length;l++) {
		imName_t = split(imNames[l],"??");
		imNames[l] = imName_t[1];
		imPath_t = split(imPaths[l],"??");
		imPaths[l] = imPath_t[1];
		recTimes[l] = imPath_t[0];
		recTimesAbs_t = split(recTimesAbs[l],"??");
		recTimesAbs[l] = recTimesAbs_t[1];
	}
	
	// Transfer timing information to results table & save.
	for (k=0;k<imNames.length;k++) {
		setResult(imNames[k], 0, imPaths[k]);
		setResult(imNames[k], 1, recTimes[k]);
		setResult(imNames[k], 2, toString(recTimesAbs[k]));
	}
	updateResults();
	if (am) {
		savePath = replace(rootdir,"alignment/","processed/timings_alignment.txt");
	}
	else {
		savePath = rootdir+"processed/"+"timings.txt";
	}
	saveAs("results", savePath);

	print("Timing log for directory "+rootdir+" created.");
	return savePath;
}
	
function parseImages(fileList) {
	// image files
	for (j=0; j<subdirFiles.length; j++) {
		if (endsWith(subdirFiles[j],".tif")) {
			// save full path to image file to array
			imName = substring(subdirFiles[j],0,lengthOf(subdirFiles[j])-4);
			imNames = Array.concat(imNames,imName);
			imPath = rootdir+subdirs[i]+subdirFiles[j];
			imPaths = Array.concat(imPaths,imPath);
			// Locate corresponding metadatafile & save full path to array
			expMetaLoc = rootdir+subdirs[i]+substring(subdirFiles[j],0,lengthOf(subdirFiles[j])-4)+"_metadata.txt";
			if (File.exists(expMetaLoc)) {
				metadataF = expMetaLoc;
				metaFiles = Array.concat(metaFiles,expMetaLoc);
				// get relative recording time and save to array
				recTime = runMacro(macroPath+fs+"extractMetadata.ijm",metadataF+","+"startTimeRel");
				recTimes = Array.concat(recTimes, recTime);
				recTimeAbs = runMacro(macroPath+fs+"extractMetadata.ijm",metadataF+","+"startTime");
				recTimesAbs = Array.concat(recTimesAbs,recTimeAbs);
			}
			else {
				print("no proper loc: "+expMetaLoc);
				metaFiles = Array.concat(metaFiles,"no metadata file found");
			}				
		}	
	}
}
