// This scripts parses _metadata.txt files to create log file with relative timings + other information for each cell(=position).
// - A second file, "timings.txt" will be created to enable ordered processing of raw data with splitALEXdata.ijm
// - Column per position, see Format info below for rows.
// - Relative timings are given w.r.t. start time of _kin dataset-delay.
// 
// Column Format
// 1 column per position
// Row: cellID
// Row: LabtekID
// Row: wellID
// Row: #frames tkin
// Row: ----
// Row: relative t0 timing
// Row: (absolute tkin start)
// Row: relative tend timing
// Row: ----
// Row: relative tkin frame timings


// input
dataP = "";
subdirs = getFileList(dataP);
macroPath = "";
delay = 4; //
fs = File.separator;

// Prepare data arrays
imNames = newArray();
ltIDs = newArray();
wellIDs = newArray();
cellIDs = newArray();
metaFiles = newArray();
startTimes = newArray();
timingReference = newArray();	// For each well, if there is a _kin dataset

// Parse through data directory and enter all image file names outside "alignment" and "flatfielding" subdirectories into array
for (i=0; i<subdirs.length; i++) {
	if (endsWith(subdirs[i],fs) && !(subdirs[i]=="alignment"+fs) && !(subdirs[i]=="flatfielding"+fs)) {
		subdirFiles = getFileList(dataP+fs+subdirs[i]);
		for (j=0; j<subdirFiles.length; j++) {
			if (endsWith(subdirFiles[j],".tif")) {
				// extract name stems for image files 
				imNames = Array.concat(imNames,substring(subdirFiles[j],0,lengthOf(subdirFiles[j])-4));
				// extract corresponding well ID
				wellIDs = Array.concat(wellIDs,substring(subdirs[i],0,lengthOf(subdirs[i])-1));
				ltIDs = Array.concat(ltIDs,substring(subdirs[i],0,4));
				// extract cellID from file name
				usI = indexOf(subdirFiles[i],"_");
				cellID = substring(subdirFiles[i],usI+1,usI+7);
				cellIDs = Array.concat(cellIDs,cellID);	
				// Locate corresponding metadatafile
				expMetaLoc = dataP+subdirs[i]+substring(subdirFiles[j],0,lengthOf(subdirFiles[j])-4)+"_metadata.txt";
				if (File.exists(expMetaLoc)) {
					metadataF = expMetaLoc;
					metaFiles = Array.concat(metaFiles,expMetaLoc);
					// get start times
					startTime = runMacro(macroPath+fs+"extractMetadata.ijm",metadataF+","+"startTimeRel");
					startTimes = Array.concat(startTimes,startTime);
				}
				else {
					metaFiles = Array.concat(metaFiles,"no File found");
				}				
			}	
		}
	}
}

// Sort result arrays into results table
order = Array.rankPositions(startTimes);
for(k=0;k<startTimes.length;k++) {
	//print(startTimes[k]);
	//print(ranks[k]);
	print(ltIDs[k]);
}
