#include <launch.h>
#include <notify.h>

#include <stdio.h>

#include <CoreFoundation/CoreFoundation.h>

launch_data_t
CF2launch_data(CFTypeRef cfr);

void
myCFDictionaryApplyFunction(const void *key, const void *value, void *context)
{
	launch_data_t ik, iw, where = context;

	ik = CF2launch_data(key);
	iw = CF2launch_data(value);

	launch_data_dict_insert(where, iw, launch_data_get_string(ik));
	launch_data_free(ik);
}

launch_data_t
CF2launch_data(CFTypeRef cfr)
{
	launch_data_t r;
	CFTypeID cft = CFGetTypeID(cfr);

	if (cft == CFStringGetTypeID()) {
		char buf[4096];
		CFStringGetCString(cfr, buf, sizeof(buf), kCFStringEncodingUTF8);
		r = launch_data_alloc(LAUNCH_DATA_STRING);
		launch_data_set_string(r, buf);
	} else if (cft == CFBooleanGetTypeID()) {
		r = launch_data_alloc(LAUNCH_DATA_BOOL);
		launch_data_set_bool(r, CFBooleanGetValue(cfr));
	} else if (cft == CFArrayGetTypeID()) {
		CFIndex i, ac = CFArrayGetCount(cfr);
		r = launch_data_alloc(LAUNCH_DATA_ARRAY);
		for (i = 0; i < ac; i++) {
			CFTypeRef v = CFArrayGetValueAtIndex(cfr, i);
			if (v) {
				launch_data_t iv = CF2launch_data(v);
				launch_data_array_set_index(r, iv, i);
			}
		}
	} else if (cft == CFDictionaryGetTypeID()) {
		r = launch_data_alloc(LAUNCH_DATA_DICTIONARY);
		CFDictionaryApplyFunction(cfr, myCFDictionaryApplyFunction, r);
	} else if (cft == CFDataGetTypeID()) {
		r = launch_data_alloc(LAUNCH_DATA_ARRAY);
		launch_data_set_opaque(r, CFDataGetBytePtr(cfr), CFDataGetLength(cfr));
	} else if (cft == CFNumberGetTypeID()) {
		long long n;
		double d;
		CFNumberType cfnt = CFNumberGetType(cfr);
		switch (cfnt) {
		case kCFNumberSInt8Type:
		case kCFNumberSInt16Type:
		case kCFNumberSInt32Type:
		case kCFNumberSInt64Type:
		case kCFNumberCharType:
		case kCFNumberShortType:
		case kCFNumberIntType:
		case kCFNumberLongType:
		case kCFNumberLongLongType:
			CFNumberGetValue(cfr, kCFNumberLongLongType, &n);
			r = launch_data_alloc(LAUNCH_DATA_INTEGER);
			launch_data_set_integer(r, n);
			break;
		case kCFNumberFloat32Type:
		case kCFNumberFloat64Type:
		case kCFNumberFloatType:
		case kCFNumberDoubleType:
			CFNumberGetValue(cfr, kCFNumberDoubleType, &d);
			r = launch_data_alloc(LAUNCH_DATA_REAL);
			launch_data_set_real(r, d);
			break;
		default:
			r = NULL;
			break;
		}
	} else {
		r = NULL;
	}
	return r;
}

CFPropertyListRef
CreateMyPropertyListFromFile(const char *posixfile)
{
	CFPropertyListRef propertyList;
	CFStringRef       errorString;
	CFDataRef         resourceData;
	SInt32            errorCode;
	CFURLRef          fileURL;

	fileURL = CFURLCreateFromFileSystemRepresentation(kCFAllocatorDefault, (const UInt8 *)posixfile, strlen(posixfile), false);
	if (!fileURL) {
		fprintf(stderr, "%s: CFURLCreateFromFileSystemRepresentation(%s) failed\n", getprogname(), posixfile);
	}
	if (!CFURLCreateDataAndPropertiesFromResource(kCFAllocatorDefault, fileURL, &resourceData, NULL, NULL, &errorCode)) {
		fprintf(stderr, "%s: CFURLCreateDataAndPropertiesFromResource(%s) failed: %d\n", getprogname(), posixfile, (int)errorCode);
	}
	propertyList = CFPropertyListCreateFromXMLData(kCFAllocatorDefault, resourceData, kCFPropertyListMutableContainers, &errorString);
	if (!propertyList) {
		fprintf(stderr, "%s: propertyList is NULL\n", getprogname());
	}

	return propertyList;
}

int main(int argc, const char *argv[]) {
    if (argc > 1) {
        fprintf(stderr, "usage: sbreload\n");
        return 1;
    }

    notify_post("com.apple.mobile.springboard_teardown");

    launch_data_t request = launch_data_alloc(LAUNCH_DATA_DICTIONARY);

    CFDictionaryRef plist = CreateMyPropertyListFromFile("/System/Library/LaunchDaemons/com.apple.SpringBoard.plist");
    if (plist == NULL) {
        fprintf(stderr, "CreateMyPropertyListFromFile() == NULL\n");
        return 2;
    }

    launch_data_t job = CF2launch_data(plist);
    if (job == NULL) {
        fprintf(stderr, "CF2launch_data() == NULL\n");
        return 3;
    }

    const char *label = launch_data_get_string(launch_data_dict_lookup(job, LAUNCH_JOBKEY_LABEL));
    launch_data_dict_insert(request, job, LAUNCH_KEY_SUBMITJOB);

    launch_data_t response;
  launch_msg:
    response = launch_msg(request);

    if (response == NULL) {
        fprintf(stderr, "launch_msg() == NULL\n");
        return 4;
    }

    if (launch_data_get_type(response) != LAUNCH_DATA_ERRNO) {
        fprintf(stderr, "launch_data_get_type() != ERRNO\n");
        return 5;
    }

    int error = launch_data_get_errno(response);
    launch_data_free(response);

    const char *string = strerror(error);

    if (error == EEXIST) {
        fprintf(stderr, "%s: %s, retrying...\n", label, string);
        sleep(1);
        goto launch_msg;
    } else if (error != 0) {
        fprintf(stderr, "%s: %s\n", label, string);
        return 6;
    }

    launch_data_free(request);

    return 0;
}
