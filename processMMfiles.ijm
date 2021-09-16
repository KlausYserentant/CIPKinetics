/////////////////////////////////////////////////////////////////////////////////////
root_dir = getArgument();

setBatchMode(true);

fs = "/";
count = 0;

rootdirlist = getFileList(root_dir);
for (i=0; i<rootdirlist.length; i++) {
		if (endsWith(rootdirlist[i], "/")) {
			print("found this folder: " + rootdirlist[i]);
			folder = root_dir + substring(rootdirlist[i], 0, lengthOf(rootdirlist[i])-1);
		    folderList(folder + fs);
		}
}

print("-----------------------------------");
print("");
print("Finished! " + count + " files moved.");
print("");
print("-----------------------------------");

/////////////////////////////////////////////////////////////////////////////////////
// Functions
/////////////////////////////////////////////////////////////////////////////////////
function folderList(dir) {
	dirlist = getFileList(dir);
	print(dir);
	for (i=0; i<dirlist.length; i++) {
		if (endsWith(dirlist[i], "/")) {
			//print("found this subfolder: " + dirlist[i]);
			folderpath = dir + substring(dirlist[i], 0, lengthOf(dirlist[i])-1);
		    folderList(folderpath + fs);
		}
		else if (endsWith(dirlist[i], "ome.tif")) {
		    print("-------  found this tif-file: " + dirlist[i] + "  ---------");
		    filepath = dir + dirlist[i];
		    extractTifFromFolder(filepath);
		}
	}
}

function extractTifFromFolder(filepath) {
	print("hey");
	folderpath = substring(filepath, 0, lastIndexOf(filepath, fs)) + fs;
	filelist = getFileList(folderpath);
	if (filelist.length == 1) {
		oldpath = filepath;
		newpath = substring(folderpath, 0, lengthOf(folderpath)-1) + ".tif";
		print("moving file from " + oldpath + " to " + newpath);
		File.rename(oldpath, newpath);
		print("deleting folder " + folderpath);
		File.delete(folderpath);
		count++;
	}
	else if (filelist.length == 2) {
		extractMetadataFromFolder(folderpath,filelist);
	}
	else {
		print("## Unexpected number of files in folder. Skipping. ##");
	}
}

function extractMetadataFromFolder(folderpath,filelist) {
	for (i=0; i<filelist.length; i++) {
		oldpath = folderpath + fs + filelist[i];
		if (endsWith(filelist[i], "_metadata.txt")) {
			newpath = substring(folderpath,0, lengthOf(folderpath)-1) + "_metadata.txt";
			print("moving file from " + oldpath + " to " + newpath);
			File.rename(oldpath, newpath);
		}
		else if (endsWith(filelist[i], ".tif")) {
			newpath = substring(folderpath,0, lengthOf(folderpath)-1) + ".tif";
			print("moving file from " + oldpath + " to " + newpath);
			File.rename(oldpath,newpath);
		}
		else  {
			print("## Unrecognized file detected. Skipping. ##");
		}
	}
	print("deleting folder " + folderpath);
	File.delete(folderpath);
	count++;
}