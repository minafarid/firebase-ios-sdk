2018-07-05 10:04:07.344192-0400 Firestore_Example_iOS[10429:99653] *** Assertion failure in auto FSTLocalStore::releaseQuery:::(anonymous class)::operator()() const(), /Users/minafarid/git/firebase-ios-sdk-minafarid/Firestore/Source/Local/FSTLocalStore.mm:409
2018-07-05 10:04:07.354974-0400 Firestore_Example_iOS[10429:99653] *** Terminating app due to uncaught exception 'NSInternalInconsistencyException', reason: 'FIRESTORE INTERNAL ASSERTION FAILED: Tried to release nonexistent query: <FSTQuery: canonicalID:restaurants|f:|ob:__name__asc|l:4711687598> (expected queryData)'
*** First throw call stack:
(
	0   CoreFoundation                      0x000000010a4871e6 __exceptionPreprocess + 294
	1   libobjc.A.dylib                     0x0000000109b1c031 objc_exception_throw + 48
	2   CoreFoundation                      0x000000010a48c472 +[NSException raise:format:arguments:] + 98
	3   Foundation                          0x000000010497264f -[NSAssertionHandler handleFailureInFunction:file:lineNumber:description:] + 165
	4   Firestore_Example_iOS               0x000000010280b457 _ZN8firebase9firestore4util8internal4FailEPKcS4_iRKNSt3__112basic_stringIcNS5_11char_traitsIcEENS5_9allocatorIcEEEE + 1655
	5   Firestore_Example_iOS               0x000000010280c609 _ZN8firebase9firestore4util8internal4FailEPKcS4_iRKNSt3__112basic_stringIcNS5_11char_traitsIcEENS5_9allocatorIcEEEES4_ + 4249
	6   Firestore_Example_iOS               0x00000001024dfe18 _ZZ30-[FSTLocalStore releaseQuery:]ENK4$_12clEv + 1128
	7   Firestore_Example_iOS               0x00000001024c6171 _ZNK20FSTTransactionRunnerclIZ30-[FSTLocalStore releaseQuery:]E4$_12EENSt3__19enable_ifIXsr3std7is_voidIDTclfp0_EEEE5valueEvE4typeEN4absl11string_viewET_ + 1457
	8   Firestore_Example_iOS               0x00000001024c5a36 -[FSTLocalStore releaseQuery:] + 1110
	9   Firestore_Example_iOS               0x0000000102714ba4 -[FSTSyncEngine stopListeningToQuery:] + 1460
	10  Firestore_Example_iOS               0x0000000102362ad2 -[FSTEventManager removeListener:] + 2354
	11  Firestore_Example_iOS               0x0000000102393ab0 __37-[FSTFirestoreClient removeListener:]_block_invoke + 304
	12  Firestore_Example_iOS               0x000000010232bc22 _ZZ34-[FSTDispatchQueue dispatchAsync:]ENK3$_1clEv + 146
	13  Firestore_Example_iOS               0x000000010232bb85 _ZNSt3__128__invoke_void_return_wrapperIvE6__callIJRZ34-[FSTDispatchQueue dispatchAsync:]E3$_1EEEvDpOT_ + 117
	14  Firestore_Example_iOS               0x000000010232b74f _ZNSt3__110__function6__funcIZ34-[FSTDispatchQueue dispatchAsync:]E3$_1NS_9allocatorIS2_EEFvvEEclEv + 95
	15  Firestore_Example_iOS               0x00000001020a4b77 _ZNKSt3__18functionIFvvEEclEv + 391
	16  Firestore_Example_iOS               0x00000001020a44b9 _ZN8firebase9firestore4util10AsyncQueue15ExecuteBlockingERKNSt3__18functionIFvvEEE + 1305
	17  Firestore_Example_iOS               0x00000001020af1ff _ZZN8firebase9firestore4util10AsyncQueue4WrapERKNSt3__18functionIFvvEEEENK3$_0clEv + 95
	18  Firestore_Example_iOS               0x00000001020af195 _ZNSt3__128__invoke_void_return_wrapperIvE6__callIJRZN8firebase9firestore4util10AsyncQueue4WrapERKNS_8functionIFvvEEEE3$_0EEEvDpOT_ + 117
	19  Firestore_Example_iOS               0x00000001020aec9f _ZNSt3__110__function6__funcIZN8firebase9firestore4util10AsyncQueue4WrapERKNS_8functionIFvvEEEE3$_0NS_9allocatorISB_EES7_EclEv + 95
	20  Firestore_Example_iOS               0x00000001020a4b77 _ZNKSt3__18functionIFvvEEclEv + 391
	21  Firestore_Example_iOS               0x00000001020f5cd3 _ZZN8firebase9firestore4util8internal13DispatchAsyncEPU28objcproto17OS_dispatch_queue8NSObjectONSt3__18functionIFvvEEEENK3$_0clEPv + 51
	22  Firestore_Example_iOS               0x00000001020f5c98 _ZZN8firebase9firestore4util8internal13DispatchAsyncEPU28objcproto17OS_dispatch_queue8NSObjectONSt3__18functionIFvvEEEEN3$_08__invokeEPv + 24
	23  libclang_rt.asan_iossim_dynamic.dylib 0x0000000103856ca3 asan_dispatch_call_block_and_release + 323
	24  libdispatch.dylib                   0x000000010ac3a779 _dispatch_client_callout + 8
	25  libdispatch.dylib                   0x000000010ac421b2 _dispatch_queue_serial_drain + 735
	26  libdispatch.dylib                   0x000000010ac429af _dispatch_queue_invoke + 321
	27  libdispatch.dylib                   0x000000010ac3f16a _dispatch_queue_override_invoke + 477
	28  libdispatch.dylib                   0x000000010ac44cf8 _dispatch_root_queue_drain + 473
	29  libdispatch.dylib                   0x000000010ac44ac1 _dispatch_worker_thread3 + 119
	30  libsystem_pthread.dylib             0x000000010b15d169 _pthread_wqthread + 1387
	31  libsystem_pthread.dylib             0x000000010b15cbe9 start_wqthread + 13
)
libc++abi.dylib: terminating with uncaught exception of type NSException
==10429== ERROR: libFuzzer: deadly signal
    #0 0x103861a47 in __sanitizer_print_stack_trace (libclang_rt.asan_iossim_dynamic.dylib:x86_64+0x5da47)
    #1 0x1254c9fc3 in fuzzer::PrintStackTrace() FuzzerUtil.cpp:206
    #2 0x125324863 in fuzzer::Fuzzer::CrashCallback() FuzzerLoop.cpp:233
    #3 0x12532472b in fuzzer::Fuzzer::StaticCrashSignalCallback() FuzzerLoop.cpp:205
    #4 0x1254cf879 in fuzzer::CrashHandler(int, __siginfo*, void*) FuzzerUtilPosix.cpp:36
    #5 0x10b14bf59 in _sigtramp (libsystem_platform.dylib:x86_64+0x1f59)
    #6 0x10b16a30a  (libsystem_pthread.dylib):x86_64+0x1030a)
    #7 0x10ad81c96 in abort (libsystem_c.dylib:x86_64+0x5bc96)
    #8 0x10ab17e6e in abort_message (libc++abi.dylib:x86_64+0x1e6e)
    #9 0x10ab1800a in default_terminate_handler() (libc++abi.dylib:x86_64+0x200a)
    #10 0x109b1c2ad in _objc_terminate() (libobjc.A.dylib:x86_64+0x52ad)
    #11 0x10ab350ad in std::__terminate(void (*)()) (libc++abi.dylib:x86_64+0x1f0ad)
    #12 0x10ab35122 in std::terminate() (libc++abi.dylib:x86_64+0x1f122)
    #13 0x10ac3a78c in _dispatch_client_callout (libdispatch.dylib:x86_64+0x378c)
    #14 0x10ac421b1 in _dispatch_queue_serial_drain (libdispatch.dylib:x86_64+0xb1b1)
    #15 0x10ac429ae in _dispatch_queue_invoke (libdispatch.dylib:x86_64+0xb9ae)
    #16 0x10ac3f169 in _dispatch_queue_override_invoke (libdispatch.dylib:x86_64+0x8169)
    #17 0x10ac44cf7 in _dispatch_root_queue_drain (libdispatch.dylib:x86_64+0xdcf7)
    #18 0x10ac44ac0 in _dispatch_worker_thread3 (libdispatch.dylib:x86_64+0xdac0)
    #19 0x10b15d168 in _pthread_wqthread (libsystem_pthread.dylib:x86_64+0x3168)
    #20 0x10b15cbe8 in start_wqthread (libsystem_pthread.dylib:x86_64+0x2be8)

NOTE: libFuzzer has rudimentary signal handlers.
      Combine libFuzzer with AddressSanitizer or similar for better crash reports.
SUMMARY: libFuzzer: deadly signal
MS: 0 ; base unit: 0000000000000000000000000000000000000000
0x0,0x6c,0x30,0x2e,
\x00l0.
artifact_prefix='/tmp/'; Test unit written to /tmp/crash-9b47eeef48241223c8b0cf7ea8b59ff9481a72f9
Base64: AGwwLg==
stat::number_of_executed_units: 11
stat::average_exec_per_sec:     3
stat::new_units_added:          0
stat::slowest_unit_time_sec:    0
stat::peak_rss_mb:              252
2018-07-05 10:04:07.992 xcodebuild[10389:99017] Error Domain=IDETestOperationsObserverErrorDomain Code=6 "Early unexpected exit, operation never finished bootstrapping - no restart will be attempted" UserInfo={NSLocalizedDescription=Early unexpected exit, operation never finished bootstrapping - no restart will be attempted}
Generating coverage data...
.
