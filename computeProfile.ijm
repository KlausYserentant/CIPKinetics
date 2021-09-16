// This script computes a illumination correction profile based on images recoreded
// from a homogeneously illuminated sample. All images matching the input identifier are 
// used for computing the averaged illumination profile

// Inputs
// 1) chID
// 2) sourceDir
// 3) saveDir

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Script
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// Parse input
tmp = split(getArgument(),"*");

if(!(tmp.length==3)) {
	exit("wrong number of arguments for function computeProfile!");
}

chID = split(tmp[0]," ");
sourceDir = tmp[1];
saveDir = tmp[2];

// perform flatfielding for each color channel in chID
setBatchMode(true);
profileList = newArray(chID.length);
for (i=0;i<chID.length;i++) {
	// Check if target directory for processed files exists
	if (!File.isDirectory(saveDir)) {
		File.makeDirectory(saveDir);
	}
	res = computeProfile(sourceDir,saveDir+File.separator+"profile_"+chID[i]+".tif",chID[i]);	
	if (res==0) {
		print("unable to compute profile for channel "+chID[i]+".");
		profileList[i] = "0";
	}
	else {
		profileList[i] = saveDir+"profile_"+chID[i]+".tif";
	}
}
// Return path to profiles
profiles = stringfromArray(profileList," ");
return profiles;
setBatchMode(false);

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Functions 
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// computeProfile
function computeProfile (datadir,saveP,chan) {
	fork=1;
	allFiles = getFileList(datadir);
	for (i=0; i<allFiles.length; i++) {	
		if (endsWith(allFiles[i],".tif") && indexOf(allFiles[i],chan)>0) {
			open(datadir+allFiles[i]);
			if(nSlices>1) {
				rename("stack");
				run("Z Project...", "projection=[Average Intensity]");
				rename("avg");
				selectWindow("stack");
				close();
			}
			else {
				rename("avg");
			}	
			if (fork==1) {
				selectWindow("avg");
				rename("avgstack");
				fork=0;
			}
			else {
				run("Concatenate...", "  title=avgstack open image1=avgstack image2=avg");
			}
		}
	}
	if (fork==1) {
		print("Warning: Missing template files: No profile for channel "+chan+" computed.");  
		return 0;
	}
	else {
		// compute profile from stack of individual images
		selectWindow("avgstack");
		run("Select All");
		run("Z Project...", "projection=[Average Intensity]");
		rename("avgavg");
		selectWindow("avgstack");
		close();
		selectWindow("avgavg");
		getStatistics(area, mean, min, max);
		setMinAndMax(0, 65536);	
		run("32-bit");
		run("Divide...", "value="+max+"");
		// Smoothing
		run("Gaussian Blur...", "sigma=10");
		// save profile
		rename("profile");
		saveAs("tiff",saveP);
		close();
		return 1;
	}
}

// Convert array to string with id as delimiter
function stringfromArray(input,id) {
	out = "";
	for (i=0;i<input.length;i++) {
		out = out+id+input[i];
	}
	return out;
}