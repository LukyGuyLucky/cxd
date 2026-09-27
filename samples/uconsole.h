#ifndef __UCONSOLE_H__
#define __UCONSOLE_H__

#include <stdlib.h>
#include <windows.h> 
#include <stdio.h> 

#define MAX_INPUT_LENGTH 255	/* fixed length (handle input limit separately)
                            	if console input buffer data > MAX_INPUT_LENGTH
                            	ReadConsole will read the rest on the next call */
#ifndef wstring
	typedef wchar_t* wstring ;
#endif 


wchar_t* mbs2wcs(const char* str) {
    if (str == NULL) return NULL;
    
    size_t len = strlen(str) + 1;
    wchar_t* wide_str = (wchar_t*)malloc(len * sizeof(wchar_t));
    if (wide_str == NULL) return NULL;
    
    size_t result = mbstowcs(wide_str, str, len);
    if (result == (size_t)-1) {
        free(wide_str);
        return NULL;
    }
    
    return wide_str;
}

LPCWSTR c2w_v3(const char* charStr) {
    int len = strlen(charStr) + 1;
    wchar_t* wStr = (wchar_t*)malloc(len * sizeof(wchar_t));
    swprintf(wStr, len, L"%S", charStr);
    return wStr;
}


// less dependancy between each functions to easier to copy single function for use
wstring to_wstr(const char* str) {
    if (str==NULL) return NULL;
	
    int len = MultiByteToWideChar(CP_UTF8, 0, str, -1, NULL, 0);
    if (len == 0) {
        return NULL;
    }
    
    wchar_t* wideStr = (wchar_t*)malloc(len * sizeof(wchar_t));
    if (wideStr == NULL) {
        return NULL;
    }
    
    MultiByteToWideChar(CP_UTF8, 0, str, -1, wideStr, len);
    
    return wideStr;
}
wstring charToWstring(const char* str) {
    if (str==NULL) return NULL;
	
    int len = MultiByteToWideChar(CP_UTF8, 0, str, -1, NULL, 0);
    if (len == 0) {
        return NULL;
    }
    
    wchar_t* wideStr = (wchar_t*)malloc(len * sizeof(wchar_t));
    if (wideStr == NULL) {
        return NULL;
    }
    
    MultiByteToWideChar(CP_UTF8, 0, str, -1, wideStr, len);
    
    return wideStr;
}
// less dependancy between each functions to easier to copy single function for use
wchar_t* L(const char* str) {
    if (str==NULL) return NULL;
	
    int len = MultiByteToWideChar(CP_UTF8, 0, str, -1, NULL, 0);
    if (len == 0) {
        return NULL;
    }
    
    wchar_t* wideStr = (wchar_t*)malloc(len * sizeof(wchar_t));
    if (wideStr == NULL) {
        return NULL;
    }
    
    MultiByteToWideChar(CP_UTF8, 0, str, -1, wideStr, len);
    
    return wideStr;
}
// less dependancy between each functions to easier to copy single function for use
wchar_t* charToWchar(const char* str) {
    if (str==NULL) return NULL;
	
    int len = MultiByteToWideChar(CP_UTF8, 0, str, -1, NULL, 0);
    if (len == 0) {
        return NULL;
    }
    
    wchar_t* wideStr = (wchar_t*)malloc(len * sizeof(wchar_t));
    if (wideStr == NULL) {
        return NULL;
    }
    
    MultiByteToWideChar(CP_UTF8, 0, str, -1, wideStr, len);
    
    return wideStr;
}
//same as charToWchar,for LPCWSTR convenient
LPCWSTR CharToLPCWSTR(const char* str) {
    if (str==NULL) return NULL;
	
    int len = MultiByteToWideChar(CP_UTF8, 0, str, -1, NULL, 0);
    if (len == 0) {
        return NULL;
    }
    
    wchar_t* wideStr = (wchar_t*)malloc(len * sizeof(wchar_t));
    if (wideStr == NULL) {
        return NULL;
    }
    
    MultiByteToWideChar(CP_UTF8, 0, str, -1, wideStr, len);
    
    return wideStr;
}

char* wcharToChar(wchar_t* wbuffer) {
    if(wbuffer==NULL) return NULL;
	
    char mbuffer[MAX_INPUT_LENGTH];
    DWORD chars_read;
    BOOL result;
    
    result = ReadConsoleW(
        GetStdHandle(STD_INPUT_HANDLE),  
        wbuffer,                         
        511,                             
        &chars_read,                    
        NULL                            
    );
    
    if (result) {
        wbuffer[chars_read] = L'\0';  
        
        if (chars_read > 0 && wbuffer[chars_read-1] == L'\n') {
            wbuffer[chars_read-1] = L'\0';
            if (chars_read > 1 && wbuffer[chars_read-2] == L'\r') {
                wbuffer[chars_read-2] = L'\0';
            }
        }
	
        int mb_size = WideCharToMultiByte(
            CP_UTF8,                    
            0,                          
            wbuffer,                    
            -1,                        
            mbuffer,                    
            sizeof(mbuffer),            
            NULL,                       
            NULL                        
        );
        
        if (mb_size > 0) {
	    char* result=(char*)malloc(sizeof(char*)*mb_size);
	    strncpy(result,mbuffer,mb_size);
	    return result;
        } else {
            printf("failed to convert to UTF-8,error code: %lu\n", GetLastError());
	    return NULL;
        }
        printf("\n");
    } else {
        printf("failed to read from input,error code: %lu\n\n", GetLastError());
	return NULL;
    }
    
}
char* readlineW() {
    wchar_t* wbuffer=(wchar_t*)malloc(sizeof(wchar_t)*MAX_INPUT_LENGTH);
    char mbuffer[MAX_INPUT_LENGTH];
    DWORD chars_read;
    BOOL result;
    
    result = ReadConsoleW(
        GetStdHandle(STD_INPUT_HANDLE),  
        wbuffer,                         
        511,                             
        &chars_read,                     
        NULL                             
    );
    
    if (result) {
        wbuffer[chars_read] = L'\0';  
        
        if (chars_read > 0 && wbuffer[chars_read-1] == L'\n') {
            wbuffer[chars_read-1] = L'\0';
            if (chars_read > 1 && wbuffer[chars_read-2] == L'\r') {
                wbuffer[chars_read-2] = L'\0';
            }
        }
	
        int mb_size = WideCharToMultiByte(
            CP_UTF8,                    
            0,                          
            wbuffer,                    
            -1,                         
            mbuffer,                    
            sizeof(mbuffer),            
            NULL,                       
            NULL                        
        );
        
        if (mb_size > 0) {
	    char* result=(char*)malloc(sizeof(char*)*mb_size);
	    strncpy(result,mbuffer,mb_size);
		
	    return result;
        } else {
            printf("failed to convert to UTF-8,error code: %lu\n", GetLastError());
	    return NULL;
        }
        printf("\n");
    } else {
        printf("failed to read from input,error code: %lu\n\n", GetLastError());
	return NULL;
    }
    
}


char* readline_with_original_wchar_input(wchar_t** original) {
    wchar_t* wbuffer=(wchar_t*)malloc(sizeof(wchar_t)*MAX_INPUT_LENGTH);
    char mbuffer[MAX_INPUT_LENGTH];
    DWORD chars_read;
    BOOL result;
    
    result = ReadConsoleW(
        GetStdHandle(STD_INPUT_HANDLE),  
        wbuffer,                        
        511,                             
        &chars_read,                     
        NULL                             
    );
    
    if (result) {
        wbuffer[chars_read] = L'\0';  
        
        if (chars_read > 0 && wbuffer[chars_read-1] == L'\n') {
            wbuffer[chars_read-1] = L'\0';
            if (chars_read > 1 && wbuffer[chars_read-2] == L'\r') {
                wbuffer[chars_read-2] = L'\0';
            }
        }

	*original=wbuffer;
	
        int mb_size = WideCharToMultiByte(
            CP_UTF8,                    
            0,                          
            wbuffer,                    
            -1,                         
            mbuffer,                    
            sizeof(mbuffer),            
            NULL,                       
            NULL                        
        );
        
        if (mb_size > 0) {
	    char* result=(char*)malloc(sizeof(char*)*mb_size);
	    strncpy(result,mbuffer,mb_size);
	    return result;
        } else {
            printf("failed to convert to UTF-8,error code: %lu\n", GetLastError());
	    return NULL;
        }
        printf("\n");
    } else {
        printf("failed to read from input,error code: %lu\n\n", GetLastError());
	return NULL;
    }
    
}
#ifdef wstring
	#undef wstring
#endif

#endif
