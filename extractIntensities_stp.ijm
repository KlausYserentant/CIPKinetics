// Script to extract intensities and metadata for timelapse data acquired using CID_xxx MicroManager script and pre-processing using CIDanalysissuite.

// Inputs
// 1) Path to exp directory
// 2) Macro path
// 3) file name spacer (e.g. "_ALEX_")
// 4) time point identifiers (Array)
// 5) image identifiers (Array)
// 6) roi identifiers (Array)

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Script
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

setBatchMode(true);

// Parse input
tmp = split(getArgument(),"*");
//tmp = split(params,"*");

if (!(tmp.length==6)) {
	exit("wrong number of input arguments!");
}
else {
	dataPath = tmp[0];
	macroPath = tmp[1];
	spacer = tmp[2];
	tps = split(tmp[3]," ");
	idents_img = split(tmp[4]," ");
	idents_roi = split(tmp[5]," ");
}

// Prepare
dummyPath = macroPath+"dummy.tif";
resultsPath = dataPath+"results_stp/";
imgPath = dataPath+"processed/corrected/";
roiPath = dataPath+"processed/rois/";

// Construct image and roi identifiers from time points and identifiers
imgIDs = newArray();
roiIDs = newArray();
for (i=0;i<tps.length;i++) {
	for (j=0;j<idents_img.length;j++) {
		imgIDs = Array.concat(imgIDs,spacer+tps[i]+idents_img[j]+"tif");
	}
	for (j=0;j<idents_roi.length;j++) {
		roiIDs = Array.concat(roiIDs,spacer+tps[i]+idents_roi[j]+"zip");
	}
}

// Construct paths table
Table.create("paths");
Table.setColumn("cellID",newArray(0),"paths");
for (j=0;j<imgIDs.length;j++) {
	Table.setColumn(imgIDs[j], newArray(0),"paths");
}
for (j=0;j<roiIDs.length;j++) {
	Table.setColumn(roiIDs[j], newArray(0),"paths");
}

// Identify datasets
cells = locateFiles(dataPath,imgIDs,roiIDs,"paths");

// Loop over cells, generate cytosol ROI and replace _cell rois for _kin and _tend
for (i=0;i<cells.length;i++) {
	// if cytosol roi is missing, generate cytosol roi from cell and mito rois
	for (j=0;j<tps.length;j++) {
		// obtain paths to correct ROIs
		if (tps[j]=="t0_" || tps[j]=="kin_afterCID_") {
			cellROI = Table.getString(spacer+"t0_"+"cell_roi.zip",i,"paths");
			print("using t0 cell roi");			
		}
		
		// replace _cell roi	
		if (tps[j]=="kin_afterCID_") {				
			print("replacing _cell roi for "+cells[i]+spacer+tps[j]);
			mitos = Table.getString(spacer+"kin_afterCID_"+"cell_roi.zip",i,"paths");
			roiManager("open",mitos);
			reps = roiManager("count");
			roiManager("reset");				
			sp = roiPath+cells[i]+spacer+"kin_afterCID_cell_roi.zip";
			duplicateROI(cellROI,sp,dummyPath,reps,"cell");
		}
		else if (tps[j]=="tend_") {
			print("replacing _cell roi for "+cells[i]+spacer+tps[j]);
			sp = roiPath+cells[i]+spacer+"tend_cell_roi.zip";
			duplicateROI(cellROI,sp,dummyPath,1,"cell");
		}
		
		else {
			cellROI = Table.getString(spacer+tps[j]+"cell_roi.zip",i,"paths");
		}
		mitoROI = Table.getString(spacer+tps[j]+"mito_roi.zip",i,"paths");
		
		// compute cytosol ROI from cell outline and mito area
		if (!File.exists(roiPath+cells[i]+spacer+tps[j]+"cyto_roi.zip")) {
			print("Computing cytosol ROI for cell "+cells[i]+tps[j]);
			cytoROI = generateCytoROI(cellROI,mitoROI,roiPath+cells[i]+spacer+tps[j]+"cyto_roi.zip",dummyPath);
		}
		else {
			cytoROI = roiPath+cells[i]+spacer+tps[j]+"cyto_roi.zip";
			print("replacing existing roi for "+cells[i]+spacer+tps[j]);
			cytoROI = generateCytoROI(cellROI,mitoROI,roiPath+cells[i]+spacer+tps[j]+"cyto_roi.zip",dummyPath);
		}

		// Add path to paths table
		Table.set(spacer+tps[j]+"cyto_roi.zip",posArray(cells[i],cells),cytoROI,"paths");
	}
}


// Add cytosol roi to idents_roi array
idents_roi = Array.concat(idents_roi,"cyto_roi.");

// Loop over cells, extract intensities
for (i=0;i<cells.length;i++) {
	print("Extracting intensity information from rois for cell "+cells[i]);
	// generate intensity table
	Table.create(cells[i]);
	saveP = dataPath+"processed/results_stp/"+cells[i]+"_intensities.csv";

	// loop over time points (t0, tkin, tend), extract intensities and add to cell results table
	for (j=0;j<tps.length;j++) {

		// idents_img
		for (k=0;k<idents_img.length;k++) {
			imgP = Table.getString(spacer+tps[j]+idents_img[k]+"tif", posArray(cells[i],cells),"paths");
			open(imgP);
			imName = getTitle();
			
			// idents_roi
			for (l=0;l<idents_roi.length;l++) {
				name = tps[j];
				col = substring(idents_img[k],0,lengthOf(idents_img[k])-1)+"_"+substring(idents_roi[l],0,indexOf(idents_roi[l],"_"));
				
				roiP = Table.getString(spacer+tps[j]+idents_roi[l]+"zip",posArray(cells[i],cells),"paths");

				extractIntensities(imName,roiP,col,j,name,cells[i],dummyPath,cells[i]);			
			}
			close(imName);
		}
		
	}

	// Determine path to metadata file
	t0meta = dataPath+substring(cells[i],0,6)+"/"+cells[i]+spacer+"t0_metadata.txt";
	if (File.exists(t0meta)) {
		t0Start = extractStartTime(t0meta);
	}
	tendmeta = dataPath+substring(cells[i],0,6)+"/"+cells[i]+spacer+"tend_metadata.txt";
	if (File.exists(tendmeta)) {
		tendStart = extractStartTime(tendmeta);
	}
	kinmeta = dataPath+substring(cells[i],0,6)+"/"+cells[i]+spacer+"kin_afterCID_metadata.txt";
	if (File.exists(kinmeta)) {
		kinStart = extractStartTime(kinmeta);
		frameStarts = extractFrameTime(kinmeta);
	}
	// Add to results table
	Table.set("FrameTimeAbs", 0, t0Start);
	Table.set("FrameTimeRel", 0, 0);
	Table.set("FrameTimeAbs", 1, tendStart);
	Table.set("FrameTimeRel", 1, tendStart-t0Start);

	// Results table format
	if(!File.isDirectory(dataPath+"processed/results_stp")) {
		File.makeDirectory(dataPath+"processed/results_stp");
	}
	saveAs("results",saveP);
	selectWindow(cells[i]+"_intensities.csv");
	run("Close");
}

print("done");

setBatchMode(false);

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Functions
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// Function to extract intensities from given set of images using given set of ROIs
function extractIntensities(img,roi,col,rowfOffset,name,cellID,dummy,resTable) {
	// Load rois
	print(roi);
	roiManager("open", roi);

	// Loop over slices
	selectWindow(img);
	getDimensions(width, height, channels, slices, frames);

	for (i=1;i<=frames;i++) {
		if(i>1) {
			row = rowfOffset+i-1;
		}
		else {
			row = rowfOffset;
		}
		
		// select correct roi
		if(indexOf(roi,"cyto_")>-1) {
			roiName = "cyto_"+i;
			col_area = "area_cyto";
			roiIdx = roiByName(roiName,dummy);
		}
		else if (indexOf(roi,"cell_")>-1) {
			roiName = "cell_"+i;
			col_area = "area_cell";
			roiIdx = roiByName(roiName,dummy);	
		}
		else if (indexOf(roi,"mito_")>-1) {
			roiName = "mito_"+i;
			col_area = "area_mito";
			roiIdx = roiByName(roiName,dummy);
		}
		roiManager("select",roiIdx);

		if (nSlices>1) {
			Stack.setFrame(i);
		}
		
		// measure intensity
		getStatistics(area, mean, min, max, std, histogram);

		// transfer to results table
		if(nSlices>1) {
			Table.set("name",row,name+i,resTable);
		}
		else {
			Table.set("name",row,name,resTable);
		}
		Table.set("cellID",row,cellID,resTable);
		Table.set(col, row, mean,resTable);
				
		// Add roi area to results table
		Table.set(col_area,row,area,resTable);

		// Add full frame intensity to results table
		run("Select All");
		getStatistics(area, mean, min, max, std, histogram);
		if (indexOf(img,"488nm")>-1) {
			fullframeCol = "fullframe_488nm";
		}
		else if (indexOf(img,"561nm")>-1) {
			fullframeCol = "fullframe_561nm";
		}
		Table.set(fullframeCol,row,mean,resTable);
		Table.update(resTable);
	}
	roiManager("reset");
}


// Function to identify suited images for segmentation. Recursively parses directories 
function locateFiles(expPath,imgIdentifiers,roiIdentifiers,resTable) {
	// Prepare
	hits = newArray(0);
	imPath = expPath+"processed/corrected/";
	roiPath = expPath+"processed/rois/";
	imgs = getFileList(imPath);
	rois = getFileList(roiPath);

	// Loop over images, compare against identifier
	for (i=0; i<imgs.length; i++) {
	
		// For each file, check if file name matches identifier
		if (compArray(imgs[i],imgIdentifiers)) {
			cellID = substring(imgs[i],0,13);
		
			// For each cellID, check if entry in results table already exists
			if (hits.length>0) {
				// If not, add to hits array
				if (!compArray(cellID,hits)) {

					hits = Array.concat(hits,cellID);
					rowIdx = hits.length-1;
				}
				// If yes, determine position in array
				else {
					rowIdx = posArray(cellID,hits);
				}
			}
			else {
				hits = newArray(cellID);
				rowIdx = 0;	
			}

			// Add image path to cell table
			ident = substring(imgs[i],13,lengthOf(imgs[i]));
			Table.set(imgIdentifiers[posArray(ident,imgIdentifiers)],rowIdx,imPath+imgs[i],resTable);
			Table.set("cellID",rowIdx,cellID,resTable);
		
			// check if corresponding roi sets exists
			roiCheck = newArray(roiIdentifiers.length);
			for (j=0;j<roiIdentifiers.length;j++) {
				if (File.exists(roiPath+cellID+roiIdentifiers[j])) {
					Table.set(roiIdentifiers[j], rowIdx, roiPath+cellID+roiIdentifiers[j],resTable);
				}
				else {
					print("missing roi set: "+cellID+roiIdentifiers[j]);
				}		
			}		
		}
		else {
			print("unexpected file: "+imgs[i]);		
		}	
	}
	// Remove incomplete rows from results table
	del = newArray(0);
	for(i=0;i<Table.size(resTable);i++) {
		cols = split(Table.headings(resTable),"	");
		for (j=0;j<cols.length;j++) {
			if (Table.get(cols[j], i,resTable)==0) {
				del = Array.concat(del,i);
				print("Incomplete file set found. Deleting cell "+Table.getString("cellID",i,resTable));
				j=cols.length;
			}
		}
	}
	for(i=0;i<del.length;i++) {
		Table.deleteRows(del[del.length-1-i], del[del.length-1-i],resTable);
	}
	hits = Table.getColumn("cellID",resTable);
	return hits;
}

// Function to generate n repetitions of single roi
function duplicateROI(roiPath,savePath,dummy,reps,stem) {
	open(dummy);
	img = getTitle();
	for (i=0;i<reps;i++) {
		roiManager("open",roiPath);
		roiManager("select",i);
		roiManager("rename",stem+"_"+i+1);
	}
	close(img);
	roiManager("save", savePath);
	roiManager("reset");		
}

// Function to compute cytosol from cell and mito rois
function generateCytoROI(cellROI,mitoROI,savePath,dummy) {
	// Validate # of rois in both ROI sets
	roiManager("open", cellROI);
	noCell = roiManager("count");
	roiManager("reset");
	
	roiManager("open", mitoROI);
	noMito = roiManager("count");
	roiManager("reset");

	// if pairs of rois are contained in roi set, compute frame-wise XOR roi
	if (noCell==noMito) {
		roiManager("open",cellROI);
		roiManager("open",mitoROI);
				
		tp = roiManager("count")/2;
		for (i=1;i<=tp;i++) {
			roiNo = roiManager("count");
			// select correct rois
			roiMito = roiByName("mito_"+i,dummy);
			//roiCell = roiByName("kin_cell_"+i,dummy);
			roiCell = roiByName("cell_"+i,dummy);

			// compute cytosol roi
			tmp = getList("image.titles");
			if (tmp.length==0) {
				open(dummy);
				dummyImg=true;
			}
			else {
				dummyImg=false;
			}
			roiManager("select",newArray(roiCell,roiMito));
			roiManager("XOR");
			roiManager("add");
			roiManager("select",roiNo);
			roiManager("rename","cyto_"+i);

			// delete template rois
			roiManager("deselect");
			roiManager("select",roiMito);
			roiManager("delete");
			roiManager("select",roiCell);
			roiManager("delete");
		}
		if (dummyImg) {
			close("dummy.tif");
		}
		roiManager("save", savePath);
		roiManager("reset");
				
	}
	// if single cellROI is encountered, 
	else if (noCell==1 && noMito>1) {
		roiManager("open",cellROI);
		roiManager("open",mitoROI);	
		tp = noMito;
		for (i=1;i<=tp;i++) {
			roiNo = roiManager("count");
			// select correct rois
			roiMito = roiByName("mito_"+i,dummy);
			roiCell = 0;

			// compute cytosol roi
			tmp = getList("image.titles");
			if (tmp.length==0) {
				open(dummy);
				dummyImg=true;
			}
			else {
				dummyImg=false;
			}
			roiManager("select",newArray(roiCell,roiMito));
			roiManager("XOR");
			roiManager("add");
			roiManager("select",roiNo);
			roiManager("rename","cyto_"+i);

			// delete template rois
			roiManager("deselect");
			roiManager("select",roiMito);
			roiManager("delete");
		}
		if (dummyImg) {
			close("dummy.tif");
		}
		roiManager("select", roiCell);
		roiManager("delete");
		roiManager("save", savePath);
		roiManager("reset");
	}
	else {
		exit("unexpected number of ROIs found. Aborting!");
	}
	
	return savePath;
}

// Function to convert input roi name into roi index of first roi with matching name
function roiByName(roiName,dummy) {
	if(roiManager("count")>0) {
		tmp = getList("image.titles");
		if (tmp.length==0) {
			open(dummy);
			dummyImg=true;
		}
		else {
			dummyImg=false;
		}
		pos = -1;
		
		for (i=0;i<roiManager("count");i++) {
			roiManager("select",i);
			roi =  Roi.getName;
			if (roi==roiName) {
				pos = i;
			}
		}
		if (dummyImg) {
			close("dummy.tif");
		}
	}
	else {
		print("ROI Manager does not contain any ROIs.");
		pos = -1;
	}
	return pos;
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

// Function to return index of first occurrence of string in array. Returns position or -1 if not in array
function posArray(string,array) {
	comps = newArray(array.length);
	for (j=0;j<array.length;j++) {
		if(array[j]==string) {
			comps[j]=j;
		}
		else {
			comps[j]=-1;
		}
	}
	comps = Array.sort(comps);
	pos = -1;
	i=0;
	while (pos==-1 && i<comps.length) {
		pos = comps[i];
		i=i+1;
	}
	return pos;
}

function extractFrameTime(metaFile) {
	metadata = File.openAsString(metaFile);
	pLines =split(metadata,"\n");
	times = newArray(0);

	for (i=0;i<pLines.length;i++) {
		if (startsWith(pLines[i],"  \"ElapsedTime-ms\": ")) {
			currentTime = parseInt(substring(pLines[i],indexOf(pLines[i],": ")+2,indexOf(pLines[i],",")))/1000;
			times = Array.concat(times,currentTime);
		}
	}
	return times;
}

function extractStartTime(metaFile) {
	metadata = File.openAsString(metaFile);
	pLines =split(metadata,"\n");

	for (i=0;i<pLines.length;i++) {
		
		if (startsWith(pLines[i],"  \"StartTime\": \"")) {
			startTime = substring(pLines[i],indexOf(pLines[i],":")+2,lengthOf(pLines[i])-1);
		}
	}
	timesec = convertTime(startTime);
	return timesec;	
}

// Converts time string to time in seconds since start of year. Assumes all months = 30 days.
function convertTime(mTime) {
	// First, get rid of extra stuff
	parts = split(substring(mTime,12,20),":");
	hours = parseInt(parts[0]);
	mins = parseInt(parts[1]);
	secs = parseInt(parts[2]);
	// Calculate time in seconds from time
	daytime = 3600*hours+60*mins+secs;
	// Call date2sec to convert date to seconds
	datetime = date2sec(mTime);
	yeartime = daytime + datetime;
	return yeartime;
}

// Function to convert time string in Micro-Manager metadate to time since start of year in seconds.
function date2sec(date) {
	m = substring(date,6,8);
	d = substring(date,9,11);
	if (m=="Jan" || "01") { mp =1;}
	else if (m=="Feb" || "02") {mp = 2;}
	else if (m=="Mar" || "03") {mp = 3;}
	else if (m=="Apr" || "04") {mp = 4;}
	else if (m=="May" || "05") {mp = 5;}
	else if (m=="Jun" || "06") {mp = 6;}
	else if (m=="Jul" || "07") {mp = 7;}
	else if (m=="Aug" || "08") {mp = 8;}
	else if (m=="Sep" || "09") {mp = 9;}
	else if (m=="Oct" || "10") {mp = 10;}	
	else if (m=="Nov" || "11") {mp = 11;}
	else if (m=="Dec" || "12") {mp = 12;}
	mp = (mp-1)*2592000;
	d = (parseInt(d)-1)*86400;
	return mp+d;
}