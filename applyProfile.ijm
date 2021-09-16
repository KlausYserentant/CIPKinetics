// This script applies a provided intensity profile for flatfielding of all images matching the 
// channel identifier in a target directory. Data will be saved to specified directory.
//
// Inputs
// 1) chiID: Channel identifier [string]
// 2) profile: Path to intensity profile [string, *.tif]
// 3) targetDir: Target directory containing channel-split images with channel identifiers in file name (*_XXXnm.tif)
// 4) saveDir: Save directory

// Parse input
tmp = split(getArgument(),"*");

if(!(tmp.length==4)) {
	exit("wrong number of arguments for function computeProfile!");
}

chID = tmp[0];
profile = tmp[1];
targetDir = tmp[2];
saveDir = tmp[3];


//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Script
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

setBatchMode(true); 

open(profile);
rename("profile");
processDir(targetDir,lengthOf(targetDir),saveDir,chID);
close("profile");

setBatchMode(false);
return;

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Functions 
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// Function which corrects illumination of target image using specified profile. Take pixel size into account
function applyProfile (targetP,saveP,chan) {
			// Check if profile has been opened
			if (isOpen("profile")) {
				selectWindow("profile");
				pxProfile = adjustedPxSize("profile");
				getDimensions(widthProfile, heightProfile,t1,t2,t3);
			}
			else {
				print("No profile template opened. Aborting!");
				return;
			}
			
			// Open target image
			open(targetP);
			rename("target");
			
			// Compare pixel sizes
			pxTarget = adjustedPxSize("target");
			getDimensions(widthTarget, heightTarget,t1,t2,t3);
			// If profile and target have identical size, do nothing
			if (pxProfile-pxTarget<0.1 && heightProfile == heightTarget) {
				selectWindow("profile");
				run("Duplicate...", " ");
				rename("profile_final");
			}
			// If profile is larger than target, modify profile
			else if (pxProfile*heightProfile > pxTarget*heightTarget) {
				selectWindow("profile");
				factor = (pxTarget*heightTarget)/(pxProfile*heightProfile);
				// choose subregion from ff profile
				sizeTmp = factor*heightProfile;
				spacing = (heightProfile-sizeTmp)/2;
				makeRectangle(spacing, spacing, sizeTmp, sizeTmp);
				run("Duplicate...", " ");				
				rename("profile_tmp");
				// scale to identical pixel number as target
				run("Scale...", "width="+heightTarget+" height="+heightTarget+" interpolation=None average create");
				rename("profile_final");
				close("profile_tmp");
			}
			// If profile is smaller, abort
			else {
				print("profile too small. Aborting!");
				return;
			}

			setMinAndMax(0, 65536);
			run("32-bit");
			imageCalculator("Divide create 32-bit stack", "target","profile_final");
			setMinAndMax(0.00, 65535.0);
			run("16-bit");

			// compile path + file name for saving flatfielded image
			start = lastIndexOf(targetP,"/");			

			nn = substring(targetP,start,lastIndexOf(targetP,chan))+"ff_"+chan+".tif";

			//nn = substring(targetP,start+1,lengthOf(targetP)-4)+"_ff.tif";
			rename(nn);
			save(saveP+"/"+nn);
			close(nn);
			close("target");
			close("profile_final");
}

// Function to identify suited images for flatfielding. Recursively parses directories 
function processDir(currentP,pathOffset,saveP,chan) {
	files = getFileList(currentP);
	for (i=0; i<files.length; i++) {
		// For all directories, except non-data directories (flatfielding, alignment, processing) recursively call processDir
		if (endsWith(files[i], "/") && !(files[i]=="flatfielding/") && !(files[i]=="alignment/")) {
			folderpath = currentP + substring(files[i], 0, lengthOf(files[i])-1)+"/";
		    processDir(folderpath,pathOffset,saveP,chan);
		}
		// Process all images with matching channel identifier 
		else if (endsWith(files[i],".tif") && indexOf(files[i],chan)>-1 && indexOf(files[i],"_ff_")==-1 && indexOf(files[i],"profile_")==-1) {
			// Check if directory for saving data exists
			fullsaveP = saveP+substring(currentP,pathOffset,lengthOf(currentP));

		    // call applyProfile
			applyProfile(currentP+"/"+files[i],saveP,chan);	    
		}
	}
}

// Extracts pixel size in nm from image metadata. Will open dialoge if unexpected pixel size is encountered
function adjustedPxSize(imName) {
	selectWindow(imName);
	getPixelSize(pxUnit, pxWidth, pxHeight);
	if (pxUnit!="nm" && pxUnit!="nanometer" && pxUnit!="um" && pxUnit!=getInfo("micrometer.abbreviation") && pxUnit!="micrometer") { 
		Dialog.create("Pixel size");
		Dialog.addMessage("Specify pixel size");
		Dialog.addNumber("Size", 96);
		Dialog.addToSameRow();
		Dialog.addChoice("Unit", newArray("nm","µm"));
		Dialog.show();
		pxWidth = Dialog.getNumber();
		pxUnit = Dialog.getChoice();
	}
	if (pxUnit=="nm" || pxUnit=="nanometer") {
		output = pxWidth;
		pxUnit = "nm";
	}
	else if (pxUnit=="um" || pxUnit==getInfo("micrometer.abbreviation") || pxUnit=="micrometer") {
		output = pxWidth*1000;
		pxUnit = "nm";
	}
	return output;
}