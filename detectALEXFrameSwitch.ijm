// New version of detectALEXFrameSwitch to replace detectALEXFrameSwitch eventually

// Inputs
// 1) Initial channel order
// 2) Path to timings.log
// 3) Input directory
// 4) Output directory

// Parse input
tmp = split(getArgument(),"*");
chanListStart = split(tmp[0]," ");
pathTimings = tmp[1];
pathInput = tmp[2];
pathOutput = tmp[3];
logname = tmp[4];

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Script
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

setBatchMode(true);

// Define required variables
fNames = parseTimings(pathTimings,0);
fPaths = parseTimings(pathTimings,1);
chanList = newArray();
pastLT = "";
newLT = true;
print("\\Clear");

// Loop over entries in fNames and perform ALEXcheck for each entry using corresponding file in fPaths.
for (i=1; i<fNames.length; i++) {
	// Reset variables
	switchFlag = 1;
	switchPos=0;
	
	// Open file
	currentPath = fPaths[i];
	print("["+i+"/"+fNames.length+"] Checking file: "+fPaths[i]);
	open(fPaths[i]);
	
	imName = getTitle();
	// Remove ".tif" from file name
	if (indexOf(imName,".tif")>-1) {
		imName = substring(imName,0,indexOf(imName,".tif"));
		rename(imName);
	}
	
	// Check if current file is in different Labtek than previous file. If so, reset chanList.
	currentLT = substring(File.getParent(currentPath), lengthOf(File.getParent(currentPath))-6, lengthOf(File.getParent(currentPath))-2);
	if (currentLT==pastLT) {
		newLT = false;
		print("Current channel order: "+chanList[0]+","+chanList[1]);
	}
	else {
		print("New channel order: "+chanListStart[0]+","+chanListStart[1]);
		chanList = chanListStart;
	}

	type=1;
	chanList_tmp = chanList;
	
	while (type>0) {
		// Initial test with full frame intensity
		Table.create("intInfo");
		selectWindow(imName);
		drawROI(imName,"all");
		extractParams(imName);
		Table.update("intInfo");
		out = validateALEXstack(imName,"intInfo");
		tmp = split(out,"*");
		pos = parseInt(tmp[1]);
		type = parseInt(tmp[0]);
		override = parseInt(tmp[2]);
		Table.reset("intInfo");

		// If initial test indicates event, test again with local intensities
		if(override==1) {
			type2=type;
		}
		else if(type>1 && override==0) {
			//print("checking with different roi");
			Table.create("intInfo");
			selectWindow(imName);
			drawROI(imName,"smallcircles");
			extractParams(imName);
			Table.update("intInfo");
			out = validateALEXstack(imName,"intInfo");
			tmp = split(out,"*");
			pos = parseInt(tmp[1]);
			type2 = parseInt(tmp[0]);
			Table.reset("intInfo");
		}
		else {
			type2=10;
		}

		// if first test and second test were positive, keep type identifier, otherwise set back to 0
		if(type==type2) {
			if (type==2) {
				print("Event at frame "+pos-1+" - none - delete");
			}
			else if (type==3) {
				print("Event at frame "+pos-1+" - double - delete");
			}
			else if (type==4) {
				print("Event at frame "+pos-1+" - switch - rearrange");
			}
			else if (type==6) {
				print("Encountered single frame image. Skipping!");
				type = 0;
			}
		}
		else {
			type = 0;
		}
		
		// Resolve switch event if type>0
		if (type>0 && type<5) {
			chanList_tmp = processALEXevent(imName,type,pos,chanList_tmp);
			print("New channel order: "+chanList_tmp[0]+","+chanList_tmp[1]);
		}

		// If irregularity in frame 1, ask for user feedback
		if (type==5) {	
			// Ask for user Feedback
			setBatchMode(false);
			prevs = prepareInfo(imName,1);
			chanList_tmp = processManually(imName,2,chanList_tmp);
			print("New channel order: "+chanList_tmp[0]+","+chanList_tmp[1]);
			type=1;		
			for (o=0;o<prevs.length;o++) {
				close(prevs[o]);
			}
			selectWindow(imName);
			setBatchMode(true);
		}
	}

	// If no event was detected or if all events were resolved, split channels and save them as separate files
	saveDir = pathOutput+"/"+substring(fPaths[i],lengthOf(pathInput),lastIndexOf(substring(fPaths[i],0,lengthOf(fPaths[i])-1),"/"));	
	recurseMakeDir(saveDir);
	splitALEXstack(imName,chanList,saveDir);

	// Prepare for processing of next file
	close(imName);
	pastLT = currentLT;
	chanList = chanList_tmp;

	// Manual override for individual dataset
	/*
	if (fNames[i]=="LT01A2_cell08_ALEX_tend") {
		chanList[0] = "488nm";
		chanList[1] = "561nm";
	}
	*/
		
}

// Save log file
selectWindow("Log");
saveAs("text",pathOutput+logname);
//print("\\Clear");	

setBatchMode(false);

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Functions
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// Function to recursively create directories
function recurseMakeDir(path) {
	subdirs = split(path,"/");
	for (i=0;i<subdirs.length;i++) {
		index1=indexOf(path,subdirs[i])+lengthOf(subdirs[i]);
		currentPath = substring(path,0,index1);		
		if (!File.isDirectory(currentPath)) {
			//index0=indexOf(path,subdirs[i-1])+lengthOf(subdirs[i-1]);
			//print("creating subdir \""+substring(path,index0+1,index1)+"\".");
			File.makeDirectory(currentPath);
		}
	}
}

// Function to extract file names + correspondings paths from timings log file
function parseTimings(timingsPath,row) {
	tempF = File.openAsString(timingsPath);
	pLines = split(tempF,"\n");
	out = split(pLines[row],"	");
	return out;
}

// Function to extract relevant parameters for ALEX validation
function extractParams(stackN) {
	selectWindow(stackN);	
	getDimensions(width, height, channels, slices, frames);

	// For some data, slices and frames are swapped. Make sure that timelapse images are registered as frames
	if (frames==1 && slices>1) {
		print("Swapping slices and frames in hyperstack! for image "+stackN);
		run("Re-order Hyperstack ...", "channels=[Channels (c)] slices=[Frames (t)] frames=[Slices (z)]");
	}

	// Create results arrays
	iCh1 = newArray(frames);
	minCh1 = newArray(frames);
	sdCh1 = newArray(frames);
	iCh2 = newArray(frames);
	minCh2 = newArray(frames);
	sdCh2 = newArray(frames);
	iM = newArray(frames);

	// Adjust image properties
	Stack.setPosition(1, 1, 1);
	setMinAndMax(0, 65536);
	Stack.setPosition(2, 1, 1);
	setMinAndMax(0, 65536);

	// Loop over frames, extract parameters
	for (i=0; i<frames;i++) {
		// Read out min, mean intensities & standard deviations for both channels
		Stack.setPosition(1, 1, i+1);
 		getRawStatistics(nPixels, iCh1[i], minCh1[i], max, sdCh1[i], histogram);
 		Stack.setPosition(2, 1, i+1);
 		getRawStatistics(nPixels, iCh2[i], minCh2[i], max, sdCh2[i], histogram);
		iM[i] = iCh1[i]+iCh2[i];
	}

	// Transfer results arrays to table for transfer to downstream analysis
	Table.setColumn("iCh1", iCh1,"intInfo");
	Table.setColumn("minCh1", minCh1,"intInfo");
	Table.setColumn("sdCh1", sdCh1,"intInfo");
	Table.setColumn("iCh2", iCh2,"intInfo");
	Table.setColumn("minCh2", minCh2,"intInfo");
	Table.setColumn("sdCh2", sdCh2,"intInfo");
	Table.setColumn("iM", iM,"intInfo");
}

// Function to create different types of ROIs within image
function drawROI(stackN,roiType) {
	selectWindow(stackN);
	if (roiType=="circle") {
		makeOval(128, 128, 256, 256);
	}
	else if (roiType=="smallCircles") { // Currently doesn't work. How to add multiple selections?
		makeOval(132, 69, 36, 38);
		roiManager("add");
		makeOval(98, 251, 44, 44);
		roiManager("add");
		makeOval(153, 380, 28, 28);
		roiManager("add");
		makeOval(357, 434, 27, 27);
		roiManager("add");
		makeOval(301, 311,38, 38);
		roiManager("add");
		makeOval(214, 232, 26, 26);
		roiManager("add");
		makeOval(278, 170, 43, 43);
		roiManager("add");
		makeOval(344, 225, 23, 23);
		roiManager("add");
		makeOval(389, 141, 55, 55);
		roiManager("add");
		makeOval(259, 52, 29, 29);
		roiManager("add");
		makeOval(260, 436, 25, 25);
		roiManager("add");
		makeOval(433, 302, 22, 22);
		roiManager("add");
		makeOval(112, 149, 33, 33);
		roiManager("add");
		roiManager("select",newArray(0,1,2,3,4,5,6,7,8,9,10,11,12));
	    roiManager("combine");
	    roiManager("reset");
	    //selectWindow("ROI Manager");
	    //run("Close");
	}
	else if (roiType=="all") {
		run("Select All");
	}
	else if (roiType=="reset") {
		run("Select None");
	}
	else {
		print("Unknown roi request. Aborting");
		return;
	}
}
	
// Main function to check single file for correct ALEX illumination sequence
//		Perform Consistency check with different approaches
//		SwitchFlag = 0 --> no suspected event or all events resolved
//		switchFlag = 1 --> Initial value
//		switchFlag = 2 --> no laser event
//		switchFlag = 3 --> double laser event
//		switchFlag = 4 --> channel switch event
//		switchFlag = 5 --> manual evaluation of event
function validateALEXstack(stackN,intTable) {
	selectWindow(stackN);
	getDimensions(width, height, channels, slices, frames);
	switchPos = 0;
	switchFlag =0;
	manualCheck = false;

	if (Table.size(intTable)>1) {

		// Obtain intensity arrays from results table
		iCh1 = Table.getColumn("iCh1",intTable);
		minCh1 = Table.getColumn("minCh1",intTable);
		sdCh1 = Table.getColumn("sdCh1",intTable);
		iCh2 = Table.getColumn("iCh2",intTable);
		minCh2 = Table.getColumn("minCh2",intTable);
		sdCh2 = Table.getColumn("sdCh2",intTable);
		iM = Table.getColumn("iM",intTable);
		
		// Define temp. data structures
		Ch1Lower = newArray(frames);
		Ch2Lower = newArray(frames);
		Ch1Upper = newArray(frames);
		Ch2Upper = newArray(frames);
		Ch1LowerStd = newArray(frames);
		Ch2LowerStd = newArray(frames);
		Ch1UpperStd = newArray(frames);
		Ch2UpperStd = newArray(frames);

		// Calculate intensity differences between channels for dynamic thresholding of expected intensity in frame 1
		for (i=0;i<frames;i++) {
			// Compute intensity mean & variance tolerances
			if (i==0) {	
				diff = abs(iCh1[0]-iCh2[0]);
				ratio1 = diff/iCh1[0];
				ratio2 = diff/iCh2[0];
				diffStd = abs(sdCh1[0]-sdCh2[0]);
				ratio1Std = diffStd/sdCh1[0];
				ratio2Std = diffStd/sdCh2[0];		
			} 
	
			// Test if frame 1 has unexpected properties by comparing with frame 2
			if (i==0) {
				Ch1Lower[i] = iCh1[i+1]-(0.1*ratio1*iCh1[i+1]);
				Ch2Lower[i] = iCh2[i+1]-(0.1*ratio2*iCh2[i+1]);
				Ch1Upper[i] = iCh1[i+1]+(0.1*ratio1*iCh1[i+1]);
				Ch2Upper[i] = iCh2[i+1]+(0.1*ratio2*iCh2[i+1]);
				
			if (iM[i]<iCh1[i+1] && iM[i]<iCh2[i+1] && sdCh1[i]<sdCh1[i+1] && sdCh2[i]<sdCh2[i+1] && switchFlag==0) {
				//print("Flag: Suspected no laser event in frame "+i+1);
				switchFlag = 5;
				switchPos = i+1;
			}
			else if (iM[i]>Ch1Upper[i]+Ch2Upper[i]+0.2*iCh1[i+1]+0.2*iCh2[i+1] && switchFlag==0) {
				//print("Flag: Suspected double laser event in frame "+i+1);
				switchFlag = 5;
				switchPos = i+1;
			}
		}
		
		// Compare intensities in frame i with intensities in frame i-1 to determine if faulty illumination occurred.
		if (i>0) {
			// Compute intensity mean & variance tolerance regions
			Ch1Lower[i] = iCh1[i-1]-(0.1*ratio1*iCh1[i-1]);
			Ch2Lower[i] = iCh2[i-1]-(0.1*ratio2*iCh2[i-1]);
			Ch1Upper[i] = iCh1[i-1]+(0.1*ratio1*iCh1[i-1]);
			Ch2Upper[i] = iCh2[i-1]+(0.1*ratio2*iCh2[i-1]);

			// If difference between channels is too small, invoke manual inspection
			if (Ch1Lower[i]>Ch2Lower[i] && Ch1Lower[i]<Ch2Upper[i]) {
				print("Warning, highly similar intensities!");
				manualCheck = true;
			}
			else if (Ch1Upper[i]>Ch2Lower[i] && Ch1Upper[i]<Ch2Upper[i]) {
				print("Warning, highly similar intensities!");
				manualCheck = true;				
			}
			else if (Ch2Lower[i]>Ch1Lower[i] && Ch2Lower[i]<Ch1Upper[i]) {
				print("Warning, highly similar intensities!");
				manualCheck = true;				
			}
			else if (Ch2Upper[i]>Ch1Lower[i] && Ch2Upper[i]<Ch1Upper[i]) {
				print("Warning, highly similar intensities!");
				manualCheck = true;				
			}

			// Potential no laser event
			if (iM[i]<iCh1[i-1] && iM[i]<iCh2[i-1] && sdCh1[i]<sdCh1[i-1] && sdCh2[i]<sdCh2[i-1] && switchFlag==0) {
				//print("Flag: Suspected no laser event in frame "+i+1);
				switchFlag = 2;
				switchPos = i+1;
			}
			// Potential illumination switch event
			else if (iM[i]<Ch1Upper[i]+Ch2Upper[i] && iM[i]>Ch1Lower[i]+Ch2Lower[i] && iCh1[i]>Ch2Lower[i] && iCh1[i]<Ch2Upper[i] && switchFlag==0) {
				//print("Flag: Suspected switch12 event in frame "+i+1);
				switchFlag = 4;
				switchPos = i+1;
			}
			// Potential illumination switch event
			else if (iM[i]<Ch1Upper[i]+Ch2Upper[i] && iM[i]>Ch1Lower[i]+Ch2Lower[i] && iCh2[i]>Ch1Lower[i] && iCh2[i]<Ch1Upper[i] && switchFlag==0) {
				switchFlag = 4;	
				//print("Flag: Suspected switch21 event in frame "+i+1);
				switchPos = i+1;
	
			}
			// Potential double laser illumination event
			//else if (iM[i]>Ch1Upper[i]+Ch2Upper[i]+0.2*iCh1[i-1]+0.2*iCh2[i-1] && switchFlag==0) {
			else if (iM[i]>Ch1Upper[i]+Ch2Upper[i] && switchFlag==0) {
					//print("Flag: Suspected double laser event in frame "+i+1);
					switchFlag = 3;
					switchPos = i+1;
				}			
			}
		}

		// uncomment to force manual check of image sequence
		//manualCheck = true;
		
		// Manual check
		if (manualCheck) {
			override=1;
			setBatchMode(false);
			infoPlot(iM, iCh1, iCh2, Ch1Lower, Ch1Upper, Ch2Lower, Ch2Upper, stackN);
			waitForUser("check");
			tmp1 = manualEvent();
			tmp2 = split(tmp1,"*");
			setBatchMode(true);
			if (!(tmp2[0]==0)) {
				switchFlag = tmp2[0];
				switchPos = tmp2[1];
			}
			else {
				switchFlag=0;
			}

			close("means");
			if (isOpen("Plot Values")) {
				close("Plot Values");
			}
			
			selectWindow(stackN);
		}
		else {
			override=0;
		}
	
		// Clean up & report switchFlag and switchPos
		Table.reset(intTable);
		selectWindow(intTable);
		run("Close");
		out = toString(switchFlag)+"*"+toString(switchPos)+"*"+toString(override);
		return out;
	}
	else {
		out = toString(6)+"*"+toString(0)+"*"+toString(0);
		return out;
	}
}

// Function to remove unwanted ALEX illumination event
function processALEXevent(stackN,switchFlag,switchPos,chans) {
	// if switchFlag==4, resort stack
	if (switchFlag==4) {
		selectWindow(stackN);
		run("Select None");
		Stack.getDimensions(width, height, channels, slices, frames);

		// recover channel 1
		run("Duplicate...", "duplicate channels=1 frames=1-"+switchPos-1+"");
		rename("ch1_p1");
		selectWindow(stackN);
		run("Select None");
		run("Duplicate...", "duplicate channels=2 frames="+switchPos+"-"+frames+"");
		rename("ch1_p2");
		run("Concatenate...", "image1=ch1_p1 image2=ch1_p2 image3=[-- None --]");
		ch1Name = substring(stackN,0,lengthOf(stackN)-4)+"_"+chans[0];
		rename(ch1Name);

		// recover channel 2
		selectWindow(stackN);
		run("Select None");
		run("Duplicate...", "duplicate channels=2 frames=1-"+switchPos-1+"");
		rename("ch2_p1");
		selectWindow(stackN);
		run("Select None");
		run("Duplicate...", "duplicate channels=1 frames="+switchPos+"-"+frames+"");
		rename("ch2_p2");
		run("Concatenate...", "image1=ch2_p1 image2=ch2_p2 image3=[-- None --]");
		ch2Name = substring(stackN,0,lengthOf(stackN)-4)+"_"+chans[1];
		rename(ch2Name);

		// merge & clean up
		run("Merge Channels...", "c1="+ch1Name+" c2="+ch2Name+" create");
		close(stackN);
		selectWindow("Composite");
		run("Re-order Hyperstack ...", "channels=[Channels (c)] slices=[Frames (t)] frames=[Slices (z)]");
		rename(stackN);
		chans_new = newArray(lengthOf(chans));
		chans_new[0] = chans[1];
		chans_new[1] = chans[0];
	}
	// If switchFlag==2||3, delete event frame
	else if (switchFlag==2 || switchFlag==3) {		
		Stack.setPosition(1, 1, switchPos);
		print("Deleting frame "+switchPos+ "from sequence "+stackN+".");
		run("Delete Slice", "delete=frame");
		chans_new = chans;
	}
	return chans_new;
}

// Function to split dual channel stack, rename according to chans array and save in outPath directory
function splitALEXstack(stackN,chans,outPath) {
	selectWindow(stackN);
	fs = File.separator;
	Stack.getDimensions(width, height, channels, slices, frames);
	if(indexOf(stackN,".tif")>-1) {
		stop = indexOf(stackN,".tif");
	}
	else {
		stop = lengthOf(stackN);
	}
	ch1Name = substring(stackN,0,stop)+"_"+chans[0];
	ch2Name = substring(stackN,0,stop)+"_"+chans[1];
	run("Select None");
	run("Duplicate...", "duplicate channels=1 frames=1+-"+frames+"");
	run("Select None");
	rename(ch1Name);
	selectWindow(stackN);
	run("Duplicate...", "duplicate channels=2 frames=1+-"+frames+"");
	rename(ch2Name);	

	// Save split channels separately & clean up
	if (!File.exists(outPath+fs)) {
		File.makeDirectory(outPath+fs);
	}
	selectWindow(ch1Name);
	run("Select None");
	saveAs("tiff",outPath+fs+ch1Name);
	close();
	selectWindow(ch2Name);
	saveAs("tiff",outPath+fs+ch2Name);
	close();
}

function processManually(imName,input,chanList) {
	if (input==2) {
		guess = "no laser";
	}
	else if (input==3) {
		guess = "double laser";
	}
	else if (input==4) {
		guess = "chan switch";
	}
	// Create dialoge and process user input
	Dialog.create("Title");
	Dialog.addRadioButtonGroup("action", newArray("no event", "delete"), 1, 2, guess);
	
	Dialog.addRadioButtonGroup("channel 1",chanList, 1, chanList.length, 1);
	Dialog.addRadioButtonGroup("channel 2", chanList, 1, chanList.length, 2);
	Dialog.show();
	event = Dialog.getRadioButton();
	ch1 = Dialog.getRadioButton();
	ch2 = Dialog.getRadioButton();

	// process frame 1
	if (event=="no event") {
		return 0;
	}
	else if (event=="delete") {
		print("Event at frame "+1+" - no/double - delete");
		selectWindow(imName);
		run("Select None");
		getDimensions(width, height, channels, slices, frames);
		run("Duplicate...", "duplicate frames=2-"+frames+"");
		rename("tmp");
		close(imName);
		selectWindow("tmp");
		rename(imName);
	}
	
	// resort channels
	selectWindow(imName);
	run("Select None");
	if (chanList[0]==ch1 && chanList[1]==ch2) {
		run("Duplicate...", "title=ch1 duplicate channels=1");
		selectWindow(imName);
		run("Duplicate...", "title=ch2 duplicate channels=2");	
	}
	else {
		run("Duplicate...", "title=ch1 duplicate channels=2");
		selectWindow(imName);
		run("Duplicate...", "title=ch2 duplicate channels=1");	
	}
	close(imName);
	run("Merge Channels...", "c1=ch1 c2=ch2 create");
	rename(imName);

	// update & return chanList
	if (chanList[0]==ch1 && chanList[1]==ch2) {
		return chanList;
	}
	else {
		return newArray(chanList[1],chanList[0]);
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

// Function to enter manual event for processing
function manualEvent () {
	// Create dialoge and process user input
	Dialog.create("Manual Events");
	Dialog.addRadioButtonGroup("action", newArray("no event", "double", "no laser", "switch"), 1, 4, 1);
	Dialog.addNumber("frame", 1);
	Dialog.show();
	
	event = Dialog.getRadioButton();
	pos = Dialog.getNumber();
	if (event=="no event") {
		type=0;
	}
	else if (event=="double") {
		type=3;
	}
	else if (event=="no laser") {
		type=2;
	}
	else if (event=="switch") {
		type=4;
	}
	else {
		exit("aborting.");
	}

	return toString(type)+"*"+toString(pos+1);
}

// Function to display preview images for manual event resolving
function prepareInfo(target,frame) {
	selectWindow(target);
	run("Select None");
	getDimensions(width, height, channels, slices, frames);
	prevs = newArray(0);
	for(i=1;i<=channels;i++) {
		selectWindow(target);
		run("Duplicate...", "duplicate channels="+i+" frames="+frame+"");
		rename("f"+frame+"_ch"+i);
		selectWindow(target);
		run("Duplicate...", "duplicate channels="+i+" frames="+frame+1+"");
		rename("f"+frame+1+"_ch"+i);
		selectWindow(target);
		prevs = Array.concat(prevs,"f"+frame+"_ch"+i,"f"+frame+1+"_ch"+i);
	}
	run("Tile");
	return prevs;
}

function infoPlot(intMergeMean, intCh1Mean, intCh2Mean, intCh1Lower, intCh1Upper, intCh2Lower, intCh2Upper, sName) {
	selectWindow(sName);
	
	// Plot intensities & boundaries
	Plot.create("means", "Frame", "Intensity");	
	Plot.setColor("blue");	
	Plot.setLineWidth(2);
	Plot.add("line",intMergeMean);
	Plot.setColor("green");
	Plot.setLineWidth(2);
	Plot.add("line",intCh1Mean);
	Plot.setLineWidth(1);
	Plot.add("line",intCh1Lower);
	Plot.add("line",intCh1Upper);
	Plot.setColor("red");
	Plot.setLineWidth(2);
	Plot.add("line",intCh2Mean);
	Plot.setLineWidth(1);
	Plot.add("line",intCh2Lower);
	Plot.add("line",intCh2Upper);
	Plot.setLimits(1,frames,0,iM[0]*1.2);
	Plot.setLegend("Merge	Ch1	range Ch1		Ch2	range Ch2	");	
	Plot.show();
}
