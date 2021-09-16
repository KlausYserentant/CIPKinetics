// sort input to variables
inputRaw = getArgument();
input = split(inputRaw,",");
metadataFile = input[0];
param = input[1];

// extract metadata from metadata file.
if (param=="startTimeRel") {
	paramRaw = xtractParam(metadataFile,"startTimeRel");
	output = paramRaw;
}
else {
	paramRaw = xtractParam(metadataFile,"startTime");
	output = paramRaw;
}

// return extracted metadata. Can be int or int array!
return output;

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Functions
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

function xtractParam(metaFile,param) {
	metadata = File.openAsString(metadataFile);
	pLines =split(metadata,"\n");
	val = "";
	if (param=="frameNo") {
		ident = "  \"Frames\": ";
	}
	else if (param=="chanNo") {
		ident = "  \"Channels\": ";
	}
	else if (param=="startTime") {
		ident = "  \"Time\": ";
	}
	else if (param=="startTimeRel") {
		ident = "  \"Time\": ";
	}
	else {
		print("Did not recognize desired parameter. Aborting.");
		return ;
	}
	for (i=0;i<pLines.length;i++) {
		if (startsWith(pLines[i],ident) && !(param=="startTimeRel")) {
			val = substring(pLines[i],indexOf(pLines[i],":")+2,lengthOf(pLines[i])-1);
		}
		else if (startsWith(pLines[i],ident) && param=="startTimeRel")  {
			idx1 = indexOf(pLines[i],": \"");
			if (!(substring(pLines[i],idx1+3,idx1+4)=="2")) {
				val = substring(pLines[i],indexOf(pLines[i],":")+2,lengthOf(pLines[i])-1);
			}
		}
	}

	if (lengthOf(val)==0) {
		print("Parameter is not listed in metadata file.");
		return "0";
	}
	else {
		if (param=="startTimeRel") {
			val = convertTime(val);
		}
		return val;
	}
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
	return toString(yeartime);
}

// Function to convert time string in Micro-Manager metadate to time since start of year in seconds.
function date2sec(date) {
	m = substring(date,5,8);
	d = substring(date,9,11);
	if (m=="Jan") { mp =1;}
	else if (m=="Feb") {mp = 2;}
	else if (m=="Mar") {mp = 3;}
	else if (m=="Apr") {mp = 4;}
	else if (m=="May") {mp = 5;}
	else if (m=="Jun") {mp = 6;}
	else if (m=="Jul") {mp = 7;}
	else if (m=="Aug") {mp = 8;}
	else if (m=="Sep") {mp = 9;}
	else if (m=="Oct") {mp = 10;}	
	else if (m=="Nov") {mp = 11;}
	else if (m=="Dec") {mp = 12;}
	mp = (mp-1)*2592000;
	d = (parseInt(d)-1)*86400;
	return mp+d;
}