#include <launch.h>
#include <notify.h>

#include <stdio.h>
#include <unistd.h>

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

#define _assert(test, format, args...) do { \
    if (test) break; \
    fprintf(stderr, format "\n", ##args); \
    return 1; \
} while (false)

void stop() {
    sleep(1);
}

int main(int argc, const char *argv[]) {
    _assert(argc == 1, "usage: sbreload");

    CFDictionaryRef plist = CreateMyPropertyListFromFile("/System/Library/LaunchDaemons/com.apple.SpringBoard.plist");
    _assert(plist != NULL, "CreateMyPropertyListFromFile() == NULL");

    launch_data_t job = CF2launch_data(plist);
    _assert(job != NULL, "CF2launch_data() == NULL");

    launch_data_t data, request, response;

    data = launch_data_dict_lookup(job, LAUNCH_JOBKEY_LABEL);
    _assert(data != NULL, "launch_data_dict_lookup(LABEL) == NULL");
    const char *label = launch_data_get_string(data);

    request = launch_data_alloc(LAUNCH_DATA_DICTIONARY);
    launch_data_dict_insert(request, launch_data_new_string(label), LAUNCH_KEY_GETJOB);

    response = launch_msg(request);
    _assert(response != NULL, "launch_msg(GetJob) == NULL");
    launch_data_free(request);

    pid_t pid;

    if (launch_data_get_type(response) == LAUNCH_DATA_ERRNO) {
        int error = launch_data_get_errno(response);
        _assert(error == ESRCH, "GetJob(%s): %s", label, strerror(error));
        pid = -1;
    } else if (launch_data_get_type(response) == LAUNCH_DATA_DICTIONARY) {
        data = launch_data_dict_lookup(response, LAUNCH_JOBKEY_PID);
        _assert(data != NULL, "launch_data_dict_lookup(PID) == NULL");
        pid = launch_data_get_integer(data);
    } else _assert(false, "launch_data_get_type() not in (DICTIONARY, ERRNO)");

    launch_data_free(response);

    fprintf(stderr, "notify_post(com.apple.mobile.springboard_teardown)\n");
    notify_post("com.apple.mobile.springboard_teardown");

    if (pid != -1) {
        fprintf(stderr, "waiting for kill(%u) != 0...\n", pid);
        while (kill(pid, 0) == 0)
            stop();

        int error = errno;
        _assert(error == ESRCH, "kill(%u): %s", pid, strerror(error));
    }

    request = launch_data_alloc(LAUNCH_DATA_DICTIONARY);
    launch_data_dict_insert(request, job, LAUNCH_KEY_SUBMITJOB);

    for (;;) {
        response = launch_msg(request);
        _assert(response != NULL, "launch_msg(SubmitJob) == NULL");

        _assert(launch_data_get_type(response) == LAUNCH_DATA_ERRNO, "launch_data_get_type() != ERRNO");
        int error = launch_data_get_errno(response);
        launch_data_free(response);

        const char *string = strerror(error);

        if (error == EEXIST) {
            fprintf(stderr, "SubmitJob(%s): %s, retrying...\n", label, string);
            stop();
        } else {
            _assert(error == 0, "SubmitJob(%s): %s", label, string);
            break;
        }
    }

    launch_data_free(request);

    return 0;
}
