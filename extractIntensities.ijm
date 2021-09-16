// Script to extract intensities and metadata for timelapse data acquired using CID_xxx MicroManager script and pre-processing using CIDanalysissuite.

// Timelapse images
// 1) Create cell index
// 2) Add paths to results table
// 2.1) Check if file exists
// 2.2) Add to table
// 3) Add metadata fields to results table
// 3.1) ExpID
// 3.2) cellID
// 4) Loop over cellID array
//	- t0 img
//  - tend img
// 	- kin timelapse
// 4.1) Open img
// 4.2) Open corresponding rois
// 4.3) Create _cyto roi from _cell and _cell
// 4.4) Extract intensities from both color channels
// 4.5) Extract time stamps from metadata files

// Inputs
// 1) Path to exp directory
// 2) Macro path
// 3) file name spacer (e.g. "_ALEX_")

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Script
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// Temp input
dataPath = "/home/klaus/Desktop/CID_Kinetics_testData/KP014_20181019/";
macroPath = "/home/klaus/Desktop/diss/00_wip/CIDs/Code/CIDanalysisSuite/";
spacer = "_ALEX_";
tps = newArray("t0_","kin_afterCID_","tend_");
idents_img = newArray("ff_488nm.","ff_561nm_tf.");
idents_roi = newArray("cyto_roi.","mito_roi.");



// Parse input
tmp = split(getArgument(),"*");


sdsdf
return;

dataPath = tmp[0];
macroPath = tmp[1];
spacer = tmp[2];



params = expDir+"*"+macroPath+"*"+"_ALEX_"+"*"+"t0_ tend_ kin_afterCID_"+"*"+"ff_488nm. ff_561nm_tf."+"*"+"cell_roi. mito_roi.";


// Prepare
dummyPath = macroPath+"dummy.tif"
resultsPath = dataPath+"results/";
imgPath = dataPath+"processed/corrected/";
roiPath = dataPath+"processed/rois/";

// Construct image and roi identifiers from tps and idents
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
  
// Construct cells table
Table.create("hits");
Table.setColumn("cellID",newArray(0));
for (i=0;i<tps.length;i++) {
	for (j=0;j<idents_img.length;j++) {
		Table.setColumn(idents_img[j], newArray(0),"hits");
	}
	for (j=0;j<idents_roi.length;j++) {
		Table.setColumn(idents_roi[j], newArray(0),"hits");
	}
}

// Identify datasets
cells = locateFiles(dataPath,imgIDs,roiIDs,"hits");


Array.show(cells);
print("done");
return;


// Loop over cells
for (i=0;i<cells.length;i++) {
	
	// if cytosol roi is missing, generare cytosol roi from cell and mito rois
	
	for (j=0;j<tps.length;j++) {
		generateCytoROI(cells,mitos,"/home/klaus/Desktop/diss/00_wip/CIDs/Code/CIDanalysisSuite/test_exp4/tmp.zip",dummyPath);
	}

	// extract intensities

	// Results table format
	// - Save to resultsPath
	//	|–For each time point
}












//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Functions
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// Function to identify suited images for segmentation. Recursively parses directories 
function locateFiles(expPath,imgIdentifiers,roiIdentifiers,resTable) {
	hits = newArray(0);

	// Get all pre-processed images and rois in experiment
	imgs = getFileList(expPath+"processed/corrected");
	rois = getFileList(expPath+"processed/rois");

	// Loop over images, compare against identifier
	for (i=0; i<imgs.length; i++) {

		// For each file, check if file name matches identifier
		if (compArray(imgs[i],imgIdentifiers)) {

			
			cellID = substring(imgs[i],0,13);
			// For each hit, check if all other required files are present
				
			// For each file set, check if entry in results table already exists
			if (hits.length>0) {
				if (!compArray(cellID,hits)) {
					// If not, add to hits array and results table
					print(imgs[i]);
					hits = Array.concat(hits,cellID);
				}
				else {
					
				}	
			}
			else {
				hits = newArray(cellID);
			}
		}				
	}
		
	return hits;
}

// Function to verify existence of required files
function validateCandidates(list,spacer,tps,reqImgs,reqROIs,resName) {
	// Prepare
	paths = newArray(0);
	cellIDs = newArray(0);
	cellIDs_old = Table.getColumn("cellID",resName);
	paths_old = Table.getColumn("path",resName);
	hits = newArray(0);

	for (i=0;i<list.length;i++) {
		// Extract metadata
		path = substring(list[i],0,lastIndexOf(substring(list[i],0,lengthOf(list[i])-1),"/")+1);
		img = substring(list[i],lastIndexOf(substring(list[i],0,lengthOf(list[i])-1),"/")+1,lengthOf(list[i]));
		cellID = substring(img,0,lastIndexOf(img,"cell")+6);

		// Construct paths to required files
		reqFiles = newArray(0);
		for (tp=0;tp<tps.length;tp++) {
			for (imgFile=0;imgFile<reqImgs.length;imgFile++) {
				file = path+cellID+spacer+tps[tp]+reqImgs[imgFile]+"tif";
				reqFiles = Array.concat(reqFiles,file);
			}
			for (roiFile=0;roiFile<reqROIs.length;roiFile++) {
				roi = path+cellID+spacer+tps[tp]+reqROIs[roiFile]+"zip";
				reqFiles = Array.concat(reqFiles,roi);
			}
		}

		// Check if files exist
		count = 0;
		for (j=0;j<reqFiles.length;j++) {
			if (File.exists(reqFiles[j])) {
				count = count+1;
			}
			else {
				print(reqFiles[j]);
			}
		}
		print(count);
		print(reqFiles.length);
		print("---");

		// If all required data is present, add to results table
		if (count == reqFiles.length) {
			hits = Array.concat(hits,list[i]);
		}
		
	}
	/*
	// Add arrays to results table
	cellIDs = Array.concat(cellIDs_old,cellIDs);
	Table.setColumn("cellID", cellIDs,resName);
	paths = Array.concat(paths_old,paths);
	Table.setColumn("path",paths,resName);

	// return cleaned hit list
	return cellIDs;
	*/
	return hits;
}




// Function to extract intensities from given set of images using given set of ROIs
function extractIntensities(imgs,rois,resTable) {
	// Load rois

	// Loop over images,

		// Area
		// intensity
		// time

}

// Function to compute cytosol from cell and mito rois
function generateCytoROI(cellROI,mitoROI,savePath,dummy) {
	setBatchMode(true);
	// Validate # of rois in both ROI sets
	roiManager("open", cellROI);
	noCell = roiManager("count");
	roiManager("reset");
	
	roiManager("open", mitoROI);
	noMito = roiManager("count");
	roiManager("reset");
	
	// 
	if (noCell==noMito) {
		roiManager("open",cellROI);
		roiManager("open",mitoROI);
		tp = roiManager("count")/2;
		for (i=1;i<=tp;i++) {
			print(i);
			roiNo = roiManager("count");
			// select correct rois
			roiMito = roiByName("kin_mito_"+i,dummy);
			//roiCell = roiByName("kin_cell_"+i,dummy);
			roiCell = roiByName("kin_cyto_"+i,dummy);
			print(roiMito);
			print(roiCell);

			// compute cytosol roi
			tmp = getList("image.titles");
			if (tmp.length==0) {
				open(dummy);
				dummyImg=true;
			}
			roiManager("select",newArray(roiCell,roiMito));
			roiManager("XOR");
			roiManager("add");
			roiManager("select",roiNo);
			roiManager("rename","kin_cyto_"+i);

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
				
	}
	else {
		exit("unequal number of ROIs found. Aborting!");
	}
	setBatchMode(false);
}

// Function to convert input roi name into roi index of first roi with matching name
function roiByName(roiName,dummy) {
	if(roiManager("count")>0) {
		tmp = getList("image.titles");
		if (tmp.length==0) {
			open(dummy);
			dummyImg=true;
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