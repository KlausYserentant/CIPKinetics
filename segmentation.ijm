// Script to perform weka segmentation for all images in specified folder using pre-trained weka classifiers

// - Will create one roi (set) per image file
// - Decide which classifier to use based on channel information
// - Decide how to perform segmentation (single roi vs. frame-wise roi) based on identifier in file name

// Inputs
// 1) macroPath --> required to load models
// 2) Weka version
// 3) dataPath
// 4) channel association
// 5) skips - identifiers for images where no segmentation should be performed
// 6) max stack length submitted to Weka
// 7) segmentation threshold - good compromise 0.8

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Script
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// Parse inputs
tmp = split(getArgument(),"*");

if(tmp.length==8) {
	macroPath = tmp[0];
	vWeka = tmp[1];
	dataPath = tmp[2]+"processed/";
	tmp2 = split(tmp[3]," ");
	skips = split(tmp[4]," ");
	maxL = tmp[5];
	segThres = tmp[6];
	performWeka = tmp[7];
}
else {
	exit("Wrong number of arguments.");
}

// create channel association arrays from tmp2
chan_id = newArray();
chan_target = newArray();
if(!(tmp2.length%2==0)) {
	exit("unexpected number of parameters");
}
else{
	d=0;
	while(d<tmp2.length-1) {
		chan_id = Array.concat(chan_id,tmp2[d]);
		chan_target = Array.concat(chan_target,tmp2[d+1]);
		d=d+2;
	}
}

if (!File.isDirectory(dataPath+"segmaps/")) {
	File.makeDirectory(dataPath+"segmaps/");
}

// Identify all timelapse imagesets
tlImgs = newArray();
idents_tl = newArray("_kin_afterCID_ff_488nm.","_kin_afterCID_ff_561nm_tf.");
tlImgs = locateFiles(dataPath+"corrected/",lengthOf(dataPath)+lengthOf("corrected/"),idents_tl,tlImgs);

// Identify all single time point imagesets
stpImgs = newArray();
idents_stp = newArray("_t0_ff_488nm.","_t0_ff_561nm_tf.","_tafterCID_ff_488nm.","_tafterCID_ff_561nm_tf.","_tend_ff_488nm.","_tend_ff_561nm_tf.");
stpImgs = locateFiles(dataPath+"corrected/",lengthOf(dataPath)+lengthOf("corrected/"),idents_stp,stpImgs);

// Perform segmentation on averaged images for single time-point data

for (h=0;h<stpImgs.length;h++) {
	// Prepare Weka segmentation
	path = substring(stpImgs[h],0,lastIndexOf(stpImgs[h],"/")+1);
	img = substring(stpImgs[h],lastIndexOf(stpImgs[h],"/")+1,lengthOf(stpImgs[h]));
	if (endsWith(img,".tif")) {
		img = substring(img,0,lengthOf(img)-4);
	}

	// determine target
	target = convertIdentifier(img,chan_id,chan_target);

	// Perform segmentation if processing is not supressed by listing in skips array 
	segmap = File.exists(dataPath+"segmaps/"+img+"_map"+".tif");
	if (!compArray(img,skips) && !segmap) {
		open(stpImgs[h]);
		if (nSlices>1) {
			rename("stack");
			run("Duplicate...", "duplicate range=1-1");
			//run("Z Project...", "projection=[Average Intensity]");
			close("stack");
		}
		rename(img);
		classifier = selectClassifier(img,macroPath,chan_id,chan_target);
		
		// Perform Weka segmentation
		
		if (performWeka) {
			map = performWekaSeg(classifier,img,vWeka,maxL);
		}
		else {
			print(img);
			map = img+"_map";
			open(dataPath+"segmaps/"+map+".tif");
			rename(map);
		}
		// Convert classifier output to roi
		weka2roi(map,0,""+target,segThres,dataPath+"rois/");

		// Clean up	
		selectWindow(map);
		saveAs("tif", dataPath+"segmaps/"+map+".tif");
		close(map+".tif");
		close(img);
	}
	else {
		print("skipping :"+stpImgs[h]);
	}
}

// Perform frame-wise segmentation of time-lapse data
for (i=0;i<tlImgs.length;i++) {
	// Prepare Weka segmentation
	path = substring(tlImgs[i],0,lastIndexOf(tlImgs[i],"/")+1);
	img = substring(tlImgs[i],lastIndexOf(tlImgs[i],"/")+1,lengthOf(tlImgs[i]));
	if (endsWith(img,".tif")) {
		img = substring(img,0,lengthOf(img)-4);
	}

	// determine target
	target = convertIdentifier(img,chan_id,chan_target);

	// Perform segmentation if processing is not supressed by listing in skips array 
	segmap = File.exists(dataPath+"segmaps/"+img+"_map"+".tif");
	if (!compArray(img,skips) && !segmap) {
		open(tlImgs[i]);
		rename(img);
		classifier = selectClassifier(img,macroPath,chan_id,chan_target);
		
		// Perform Weka segmentation
		if (performWeka) {
			map = performWekaSeg(classifier,img,vWeka,maxL);
		}
		else {
			map = img+"_map";
			open(dataPath+"segmaps/"+map+".tif");
			rename(map);
		}
		
		// Convert classifier output to roi
		weka2roi(map,0,target,segThres,dataPath+"rois/");

		// Clean up	
		selectWindow(map);
		run("Select None");
		if (performWeka) {
			saveAs("tif", dataPath+"segmaps/"+map+".tif");
		}
		close(map+".tif");
		close(img);
	}
	else {
		print("skipping :"+path);
	}
}

print("done");

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Functions
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// Function to map channel identifier to weka classifier file location using channel-target referencing in chan_id and chan_target
function selectClassifier(imgP,macroP,chan_id,chan_target) {
	if (indexOf(imgP,chan_id[0])>-1) {
		path = macroP+"weka_"+chan_target[0]+".model";
	}
	else if (indexOf(imgP,chan_id[1])>-1) {
		path = macroP+"weka_"+chan_target[1]+".model";
	}		
	else path = "";
	return path;
}

function convertIdentifier(imgP,chan_id,chan_target) {
	if (indexOf(imgP,chan_id[0])>-1) {
		id = chan_target[0];
	}
	else if (indexOf(imgP,chan_id[1])>-1) {
		id = chan_target[1];
	}		
	else id = "";
	return id;
}

// Function to compare if any string in array is contained in input string. returns 1 if yes, 0 if no
function compArray(string,array) {
	cands = newArray(array.length);
	for(j=0;j<array.length;j++) {
		cands[j] = indexOf(string,array[j]);
	}
	cands_sorted = Array.sort(cands);
	if(cands_sorted[cands_sorted.length-1]>-1) {
		return true;
	}
	else {
		return false;	
	}
}

// Function to identify suited images for segmentation. Recursively parses directories 
function locateFiles(currentP,pathOffset,identifiers,hits) {
	files = getFileList(currentP);
	
	for (i=0; i<files.length; i++) {
		// For all directories, except non-data directories (flatfielding, alignment, processing) recursively call processDir
		if (endsWith(files[i], "/") && !(files[i]=="processed/") && !(files[i]=="flatfielding/") && !(files[i]=="alignment/")) {
			folderpath = currentP + substring(files[i], 0, lengthOf(files[i]));
		    hits = locateFiles(folderpath,pathOffset,identifiers,hits);
		}
		// Process all images with matching identifiers
		
		else if (endsWith(files[i],".tif")) {
			if (compArray(files[i],identifiers)) {
				hits = Array.concat(hits,currentP+files[i]);
			}
		}
		else {
		}
	}
	return hits;
}

// Function to perform weka segmentation in specified mode, using specified classifier on given image file
function performWekaSeg(classifier,img,version,cutoff) {

	wekaID = "Trainable Weka Segmentation v"+version;
	selectWindow(img);
	stackL = nSlices;
	resName = img+"_map";

	// If nSlices for img >10, split before submitting to Weka
	subs=1;
	if (stackL>=cutoff) {
		while (subs*cutoff<stackL) {
			subs = subs+1;
		}
	}
	else {
		subs=1;
	}

	// Generate substacks based on max(i)
	for (j=0;j<subs;j++) {
		selectWindow(img);
		quit = false;
		if (j<subs-1) {
			start = j*cutoff+1;
			stop = (j+1)*cutoff;
		}
		else if (j==subs-1 && !(stackL%cutoff==0)) {
			start = j*cutoff+1;
			stop = j*cutoff+(stackL%cutoff);
		}
		else if (j==subs-1 && (stackL%(cutoff)==0)) {
			start = j*cutoff+1;
			stop = (j+1)*cutoff;
		}
		else {
			quit = true;
		}
		if (!quit) {
			// Extract substack from stack
			run("Duplicate...", "title="+j+" duplicate range="+start+"-"+stop+"");
			selectWindow(j);
		
			// start Weka 
			run("Trainable Weka Segmentation");
			wait(3000);
			selectWindow(wekaID);
	
			// Load classifier
			call("trainableSegmentation.Weka_Segmentation.loadClassifier", classifier);
		
			// Apply classifier
			call("trainableSegmentation.Weka_Segmentation.getProbability");
			selectWindow(wekaID);
			close();
			selectWindow("Probability maps");
			rename("map_"+j);
			close(j);
			run("Collect Garbage");
			run("Collect Garbage");
		}
	}	
	// Join probability map stack fragments
	if (subs>1) {
		// construct concatenation string
		concstr = "";
		for (k=1;k<=subs;k++) {
			concstr = concstr+"image"+k+"=map_"+k-1+" ";
		}
		run("Concatenate...", "  title=temp open "+concstr+"");
		rename(resName);
	}
	else {
		rename(resName);
	}
	return resName;
}

// Function to convert Weka probability map to roi. Creates separate roi for each slice if nSlices>1
function weka2roi(wndow,target,prefix,threshold,saveDir) {
	// prepare
	roiManager("reset");	
	img = replace(wndow,"_488nm","");
	img = replace(img,"_561nm","");
	img = replace(img,"_map","");
	img = replace(img,"_ff","");
	img = replace(img,"_tf","");
	if (!File.isDirectory(saveDir)) {
		File.makeDirectory(saveDir);
	}

	// Determine which slice to used for generating roi
	if (indexOf(prefix,"cell")>-1) {
		chan = 1;
	}
	else if (indexOf(prefix,"mito")>-1) {
		chan = 1;
	}
	else {
		print("using input channel specification");
	}
	
	// Perform frame-wise segmentation using provided threshold value as lower bound
	selectWindow(wndow);
	
	// Format of weka probability map depends on input stack for weka. Extract relevant channel accordingly
	Stack.setChannel(chan);
	getDimensions(width, height, channels, slices, frames);	
	if (frames>1) {
		run("Duplicate...", "title=tmp duplicate channels="+chan+"");
	}
	else {
		run("Duplicate...", "title=tmp channels="+chan+"");
	}	
	
	for (h=1;h<=nSlices;h++) {
		run("Select None");
		setSlice(h);
		setThreshold(threshold, 1.0);		
		run("Create Selection");
		if(selectionType()>-1) {
			roiManager("add");
			roiManager("select",h-1);
			roiManager("rename",prefix+"_"+h);
		}
		else{
			print("no selection");
		}
	}
	close("tmp");
	
	// Save rois
	if (roiManager("count")>0) {
		indexes = newArray(roiManager("count"));
		for (i=0;i<indexes.length;i++) {
			indexes[i]=i;
		}
		roiManager("select", indexes);
		saveP = saveDir+img+"_"+prefix+"_roi.zip";
		roiManager("save selected", saveP);
	}
	roiManager("reset");
}