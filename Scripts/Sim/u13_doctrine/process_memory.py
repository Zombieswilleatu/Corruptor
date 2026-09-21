"""Best-effort resident/peak process memory, without optional dependencies."""
import os
import sys


def sample():
    result = dict(pid=os.getpid(), rss_mb=None, peak_mb=None)
    try:
        if sys.platform == 'win32':
            import ctypes
            from ctypes import wintypes
            class Counters(ctypes.Structure):
                _fields_ = [('cb', wintypes.DWORD), ('PageFaultCount', wintypes.DWORD)] + [
                    (name, ctypes.c_size_t) for name in ('PeakWorkingSetSize', 'WorkingSetSize',
                    'QuotaPeakPagedPoolUsage', 'QuotaPagedPoolUsage', 'QuotaPeakNonPagedPoolUsage',
                    'QuotaNonPagedPoolUsage', 'PagefileUsage', 'PeakPagefileUsage')]
            kernel = ctypes.WinDLL('kernel32', use_last_error=True)
            psapi = ctypes.WinDLL('psapi', use_last_error=True)
            kernel.GetCurrentProcess.restype = wintypes.HANDLE
            psapi.GetProcessMemoryInfo.argtypes = [wintypes.HANDLE, ctypes.POINTER(Counters), wintypes.DWORD]
            counters = Counters()
            counters.cb = ctypes.sizeof(counters)
            if psapi.GetProcessMemoryInfo(kernel.GetCurrentProcess(), ctypes.byref(counters), counters.cb):
                result.update(rss_mb=counters.WorkingSetSize/1048576,
                              peak_mb=counters.PeakWorkingSetSize/1048576)
        else:
            import resource
            peak = resource.getrusage(resource.RUSAGE_SELF).ru_maxrss
            result['peak_mb'] = peak/(1048576 if sys.platform == 'darwin' else 1024)
            if sys.platform.startswith('linux'):
                with open('/proc/self/statm') as stream:
                    result['rss_mb'] = int(stream.read().split()[1])*os.sysconf('SC_PAGE_SIZE')/1048576
    except (OSError, ValueError, AttributeError, ImportError):
        pass
    return {key: round(value, 2) if isinstance(value, float) else value for key, value in result.items()}
