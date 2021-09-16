// Parse input
input = getArgument();
params = split(input,"*");
expDir = params[0];
chanList = newArray(params.length-1);
for(h=1;h<params.length;h++) {
	chanList[h-1] = params[h];
}


// Prepare
fs = File.separator;
subdirs = getFileList(expDir);
alDir = "";
ffDir = "";

// Check if required calibration data can be found using directory names
for (i=0;i<subdirs.length;i++) {
	// Check for alignment directory
	if (indexOf(subdirs[i],"alignment")==0 && lengthOf(subdirs[i])==10) {
		alDir = expDir+subdirs[i];
	}
	// Check for flatfielding directory
	if (indexOf(subdirs[i],"flatfielding")==0 && lengthOf(subdirs[i])==13) {
		chanFF=newArray(chanList.length);
		tmp = getFileList(expDir+subdirs[i]);

		// Check if flatfielding templates for all required channels are present
		for (chans=0;chans<chanList.length;chans++) {
			for (j=0;j<tmp.length;j++) {
				if(indexOf(tmp[j],chanList[chans])>-1) {
					chanFF[chans]=1;
				}
			}
		}
		Array.getStatistics(chanFF, chanFFmin);
		if (chanFFmin>0) {
			ffDir = expDir+subdirs[i];
		}
	}
}

// Ask user to manually locate directories if not found
if (lengthOf(alDir)==0) {
	alDir = getDirectory("No directory with alignment templates found. Please specify manually.");
}
if (lengthOf(ffDir)==0) {
	ffDir = getDirectory("No directory with flatfielding templates found. Please specify manually.");
}

// Write files paths to log file
/*
if (!(File.isDirectory(expDir+fs+"processed"))) {
	File.makeDirectory(expDir+fs+"processed");
}

setResult("ffDir", 0, ffDir);
setResult("alDir", 0, alDir);
saveAs("results", expDir+fs+"processed"+fs+"parameters.log");
Table.reset("Results");
close("Results");

*/

// return paths 
output = alDir+"*"+ffDir;
return output;