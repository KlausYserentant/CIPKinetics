
// parse input
tmp = split(getArgument(),"*");
expDir = tmp[0];
dels = split (tmp[1]," ");
keeps = split(tmp[2]," ");
allFiles = getFileList(expDir+"processed/corrected");

setBatchMode(true);

for (i=0;i<allFiles.length;i++) {
	// Check if file is to be removed
	del=false;
	for (j=0;j<dels.length;j++) {
		if (indexOf(allFiles[i],dels[j])>-1) {
			del=true;
		}
	}
	if(del) {
		File.delete(expDir+"processed/corrected/"+allFiles[i]);
	}

	keep=false;
	for (j=0;j<keeps.length;j++) {
		if (indexOf(allFiles[i],keeps[j])>-1) {
			keep = true;
		}
	}
	if (!del && !keep && endsWith(allFiles[i],".tif")) {
		open(expDir+"processed/corrected/"+allFiles[i]);
		img = getTitle();
		if (nSlices>1) {
			run("Z Project...", "projection=[Average Intensity]");
			close(img);
			rename(img);
			saveAs("Tif",expDir+"processed/corrected/"+allFiles[i]);
		}
		close();
	}
}

setBatchMode(false);