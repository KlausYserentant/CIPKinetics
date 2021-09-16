// This script performs individual alignments for each .tif channel matching alignment

// Inputs
// 1) chIDs: String target channel identifier
// 2) root_dir: path to experiment root_dir
// 3) paramsP: absolute path to file containing averaged alignment parameters from computeAlignment.

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Script
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// parse input
setBatchMode(false);

tmp = split(getArgument(),"*");

if(!(tmp.length==3)) {
	exit("wrong number of arguments for function computeProfile!");
}

targetChan = tmp[0];
root_dir = tmp[1];
paramsP = tmp[2];


// Prepare log for image stabilizer
saveP = root_dir+"alignment_template.log";
p = prepareLog(paramsP,500,saveP);
if (p==0) {
	exit("Can't proceed without alignment template. Aborting!");
}

// Recursively crawl through root folder and process valid target images
processDir(root_dir,lengthOf(root_dir),root_dir,targetChan);
selectWindow("alignment_template.log");
run("Close");

setBatchMode(false);

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Script
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// Function to identify suited images for flatfielding. Recursively parses directories 
function processDir(currentP,pathOffset,saveP,chan) {
	files = getFileList(currentP);
	for (i=0; i<files.length; i++) {
		// For all directories, except non-data directories (flatfielding, alignment, processing) recursively call processDir
		if (endsWith(files[i], "/") && !(files[i]=="processed/") && !(files[i]=="flatfielding/") && !(files[i]=="alignment/")) {
			folderpath = currentP + substring(files[i], 0, lengthOf(files[i])-1);
		    processDir(folderpath,pathOffset,saveP,chan);
		}
		// Process all images with matching channel identifier 
		else if (endsWith(files[i],".tif") && indexOf(files[i],chan)>-1 && indexOf(files[i],"_ff_")>-1) {
			print("processing: "+files[i]);
			// Check if directory for saving data exists
			fullsaveP = saveP+substring(currentP,pathOffset,lengthOf(currentP));
			if (!File.isDirectory(fullsaveP)) {
				File.makeDirectory(fullsaveP);
			}
		    // call applyProfile
			applyAlign(currentP+File.separator+files[i],fullsaveP);
		}
		else {
			print("skipping: "+files[i]);
		}
	}
}

// Function to apply image stabilizer parameters ot new data.
function applyAlign(targetP,saveP) {
	// Open target
	open(targetP);
	// Extract path and file name from full path
	dir = substring(targetP,0,lastIndexOf(substring(targetP,0,lengthOf(targetP)-1),File.separator)+1);
	file = substring(targetP,lastIndexOf(targetP,File.separator)+1,lengthOf(targetP));
	rename("target");
	getDimensions(width, height, channels, slices, frames);
	if (frames==1) {
		// Duplicate image to create stack
		run("Duplicate...", " ");
		run("Concatenate...", "open image1=target image2=target-1 image3=[-- None --]");
		rename("target");
		// Perform transform
		run("Image Stabilizer Log Applier", " ");
		// Discard last frame
		run("Slice Remover", "first="+nSlices+" last="+nSlices+" increment=1");
		rename("target_aligned");
		close("target");
	}
	else {
		// Duplicate first frame
		run("Duplicate...", " ");
		run("Concatenate...", "  title=target open image1=target-1 image2=target");
		run("Image Stabilizer Log Applier", " ");
		// Remove duplicated first frame
		rename("target_aligned");
		run("Slice Remover", "first=1 last=1 increment=1");
		
	}
	// save transformed image (add _tf to file name)
	selectWindow("target_aligned");
	name = substring(file,0,lastIndexOf(file, "."))+"_tf.tif";
	rename(name);
	save(saveP+File.separator+name);
	close(name);
}

// Construct log file from alignments_avg
function prepareLog (paramsP,max,saveP) {
	lines=split(File.openAsString(paramsP), "\n");
	print("\\Clear");
	IJ.log("Image Stabilizer Log File for \"target\"");
	IJ.log("1");
	
	if (lines.length==7) {
		for (i=1;i<=max;i++) {
			IJ.log(i+1+",1,"+lines[1]+","+lines[2]+","+lines[3]+","+lines[4]+","+lines[5]+","+lines[6]+",");
		}
	}
	else {
		exit("Unexpected number of parameters in alignment log. Aborting!");
	}
	
	saveAs("Text", saveP);
	check = File.rename(substring(saveP,0,lengthOf(saveP)-4)+".txt", saveP);
	selectWindow("Log");
	run("Close");
	if (check==1) {
		open(saveP);
		return 1;
	}
	else {
		exit("Failed to locate transformation template. Aborting!");
	}	
}
