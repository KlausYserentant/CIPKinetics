// This script performs individual alignments for each *ALEX.tif in alignment sub directory of experiment folder.

// Inputs
// 1) chIDs: Array containing
// 2) root_dir: path to experiment root_dir

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Script
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

setBatchMode(true);

// Parse input
tmp = split(getArgument(),"*");

if(!(tmp.length==2)) {
	exit("wrong number of arguments for function computeAlignment!");
}

chIDs = split(tmp[0]," ");
root_dir = tmp[1]+"processed/alignment/";
save_dir = tmp[1]+"processed/alignment/";

setBatchMode(false);

// Check if input directory exists
if (!File.exists(root_dir)) {
	exit("Input directory does not exist");
}

// Check if output directory exists
if (!File.exists(save_dir)) {
	File.makeDirectory(save_dir);
}

// Perform alignment only if no existing aligments are located in processed subdir
tmp = getFileList(save_dir+"alignments/");
if (!File.isDirectory(save_dir) || tmp.length<2) {
	performAlignment(root_dir,save_dir,chIDs);
}
else {
	print("Using existing alignment results located in "+save_dir+".");
}

// Compile results from individual alignments
alignmentsAvg = averageAlign(save_dir);
Array.show(alignmentsAvg);
resPath = substring(save_dir,0,lengthOf(save_dir)-1)+"_avg.csv";
saveAs("results", resPath);
run("Close"); 

// Return path to avg alignment file
return resPath;

setBatchMode(false);

////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Functions
////////////////////////////////////////////////////////////////////////////////////////////////////////////

// Function to perform alignment for all *ALEX.tif files in alignment subdirectory
function performAlignment(expDir,saveDir,chans) {
	allFiles = getFileList(expDir);	
	for (i=0; i<allFiles.length; i++) {
		print(allFiles[i]);
		print(expDir+replace(allFiles[i],chans[0],chans[1]));
		if (endsWith(allFiles[i],chans[0]+".tif") && File.exists(expDir+replace(allFiles[i],chans[0],chans[1]))) {
			// open and prepare individual ALEX stack for alignment
			//prepareData(root_dir+"alignment"+File.separator+allFiles[i]);
			
			// open and prepare pre-processed ALEX stack for alignment
			prepareSplitData(root_dir+allFiles[i],chans);

			fn = substring(allFiles[i],0,lengthOf(allFiles[i])-4);
			rename(fn);		

			// align with image stabilizer
			run("Image Stabilizer", "transformation=Affine maximum_pyramid_levels=4 template_update_coefficient=0.90 maximum_iterations=10000 error_tolerance=0.000000001 log_transformation_coefficients output_to_a_new_stack");
			selectWindow("Stablized "+fn);
			rename(fn+"_aligned");
			selectWindow(fn+".log");
			fN = substring(allFiles[i],0,lengthOf(allFiles[i])-4)+"_transform.";
			saveAs("Text", saveDir+fN+"txt");
			run("Close");
			File.rename(saveDir+fN+"txt", saveDir+fN+"log");
			close("Log");

			selectWindow(fn);
			saveP = saveDir+substring(allFiles[i],0,lengthOf(allFiles[i])-4)+"_raw_avg_rgb.tif";
			imNormPlot(fn,saveP);
			
			selectWindow(fn+"_aligned");
			saveP = saveDir+File.separator+substring(allFiles[i],0,lengthOf(allFiles[i])-4)+"_corrected_avg_rgb.tif";
			imNormPlot(fn+"_aligned",saveP);
		}
	}
}

// Function to extract + average alignment parameters from log files
function averageAlign(processedP) {
	// Define required arrays
	allFiles = getFileList(processedP);
	p1 = newArray(0);
	p2 = newArray(0);
	p3 = newArray(0);
	p4 = newArray(0);
	p5 = newArray(0);
	p6 = newArray(0);
	output = newArray(6);
	// loop over log files and extract transform parameters
	for (i=0; i<allFiles.length; i++) {
		if (endsWith(allFiles[i],"transform.log")) {
			str = File.openAsString(processedP+allFiles[i]);
			lines=split(str,"\n");
			params = split(lines[3],",");
			p1 = Array.concat(p1, parseFloat(params[2]));
			p2 = Array.concat(p2, parseFloat(params[3]));
			p3 = Array.concat(p3, parseFloat(params[4]));
			p4 = Array.concat(p4, parseFloat(params[5]));
			p5 = Array.concat(p5, parseFloat(params[6]));
			p6 = Array.concat(p6, parseFloat(params[7]));
		}
	}
	// Save results to table
	Table.create("aligns");
	Table.setColumn("P1", p1,"aligns");
	Table.setColumn("P2", p2,"aligns");
	Table.setColumn("P3", p3,"aligns");
	Table.setColumn("P4", p4,"aligns");
	Table.setColumn("P5", p5,"aligns");
	Table.setColumn("P6", p6,"aligns");
	// save in processed sub dir
	saveAs("results", substring(processedP,0,lengthOf(processedP)-1)+"_complete.csv");
	run("Close");
	
	// Compute means for parameter arrays and return as output array
	/*
	Array.getStatistics(p1, min, max, mean, stdDev);
	output[0] = mean;
	Array.getStatistics(p2, min, max, mean, stdDev);
	output[1] = mean;
	Array.getStatistics(p3, min, max, mean, stdDev);
	output[2] = mean;
	Array.getStatistics(p4, min, max, mean, stdDev);
	output[3] = mean;
	Array.getStatistics(p5, min, max, mean, stdDev);
	output[4] = mean;
	Array.getStatistics(p6, min, max, mean, stdDev);
	output[5] = mean;
	*/

	output_tmp = newArray(6);
	output_tmp[0] = ArrayMedian(p1);
	output_tmp[1] = ArrayMedian(p2);
	output_tmp[2] = ArrayMedian(p3);
	output_tmp[3] = ArrayMedian(p4);
	output_tmp[4] = ArrayMedian(p5);
	output_tmp[5] = ArrayMedian(p6);

	output[0] = toString(output_tmp[0]);
	output[1] = toString(output_tmp[1]);
	output[2] = toString(output_tmp[2]);
	output[3] = toString(output_tmp[3]);
	output[4] = toString(output_tmp[4]);
	output[5] = toString(output_tmp[5]);
		
	return output;
}

// Function to compute median from array
function ArrayMedian(inpArray) {
	// Check if Array contains exclusively numbers
	i=0;
	skip=false;
	while(i<inpArray.length && !skip) {		
		if(isNaN(parseInt(inpArray[i]))) {
			return NaN;
		}
		else {
			i=i+1;
		}
	}
	
	// get input Array size
	size = inpArray.length;

	// sort Array
	tmp = Array.sort(inpArray);
	
	// If size/2==0
	if(size%2==0) {
		median = (tmp[size/2]+tmp[(size/2)-1])/2;	
	}
	// If !(size/2==0)
	else {
		median= tmp[floor(size/2)];
	}
	return median;	
}

// Function to plot a normalized rgb image from a two channel stack.
function imNormPlot(imName,saveP) {
	selectWindow(imName);
	run("Subtract Background...", "rolling=50 stack");
	setMinAndMax(0, 65536);
	run("32-bit");
	run("Make Substack...", "  slices=1");
	selectWindow("Substack (1)");
	rename("Chan01_aligned");
	getRawStatistics(nPixels, mean, min, max, std, histogram);
	run("Divide...", "value="+max+"");
	run("Green");
	setMinAndMax(0.00, 0.10);
	selectWindow(imName);
	run("Make Substack...", "  slices=2");
	selectWindow("Substack (2)");
	rename("Chan02_aligned");
	getRawStatistics(nPixels, mean, min, max, std, histogram);
	run("Divide...", "value="+max+"");
	run("Magenta");
	setMinAndMax(0.0, 0.10);
	run("Merge Channels...", "c2=["+"Chan01_aligned"+"] c6=["+"Chan02_aligned"+"] create ignore");
	rename("Im32bit");
	run("RGB Color");
	saveAs("Tiff",saveP);
	close("Im32bit");
	close(imName);
	close(substring(saveP,lastIndexOf(saveP,File.separator)+1,lengthOf(saveP)));
}

// Function to prepare data for affine alignment using the "image stabilizer" plugin
function prepareData(path) {
	open(path);
	rename("hypStack");
	run("Duplicate...", "duplicate channels=1");
	rename("chan01");
	run("Z Project...", "projection=[Average Intensity]");
	rename("chan01_avg");
	selectWindow("chan01");
	close();
	selectWindow("hypStack");
	run("Duplicate...", "duplicate channels=2");
	rename("chan02");
	run("Z Project...", "projection=[Average Intensity]");
	rename("chan02_avg");
	selectWindow("chan02");
	close();
	selectWindow("hypStack");
	close();
	run("Concatenate...", "  title=stack_avg image1=chan01_avg image2=chan02_avg");
	selectWindow("stack_avg");	
}

// Function to prepare pre-processed ALEX data for affine alignment using the "image stabilizer" plugin
function prepareSplitData(path,chans) {
	open(path);
	rename("chan01");
	run("Z Project...", "projection=[Average Intensity]");
	rename("chan01_avg");
	selectWindow("chan01");
	close();
	open(replace(path,chans[0],chans[1]));
	rename("chan02");
	run("Z Project...", "projection=[Average Intensity]");
	rename("chan02_avg");
	selectWindow("chan02");
	close();
	run("Concatenate...", "  title=stack_avg image1=chan01_avg image2=chan02_avg");
	selectWindow("stack_avg");	
}

// Convert array to string with id as delimiter
function stringfromArray(input,id) {
	out = "";
	for (i=0;i<input.length;i++) {
		out = out+id+input[i];
	}
	return out;
}