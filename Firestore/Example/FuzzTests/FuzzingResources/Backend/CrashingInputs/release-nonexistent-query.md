2018-07-05 10:10:20.561627-0400 Firestore_Example_iOS[12899:115013] *** Assertion failure in auto FSTLocalStore::releaseQuery:::(anonymous class)::operator()() const(), /Users/minafarid/git/firebase-ios-sdk-minafarid/Firestore/Source/Local/FSTLocalStore.mm:409
2018-07-05 10:10:20.572527-0400 Firestore_Example_iOS[12899:115013] *** Terminating app due to uncaught exception 'NSInternalInconsistencyException', reason: 'FIRESTORE INTERNAL ASSERTION FAILED: Tried to release nonexistent query: <FSTQuery: canonicalID:restaurants|f:|ob:__name__asc|l:2905761384042> (expected queryData)'
*** First throw call stack:
(
	0   CoreFoundation                      0x000000010a3531e6 __exceptionPreprocess + 294
	1   libobjc.A.dylib                     0x00000001099e8031 objc_exception_throw + 48
	2   CoreFoundation                      0x000000010a358472 +[NSException raise:format:arguments:] + 98
	3   Foundation                          0x000000010483e64f -[NSAssertionHandler handleFailureInFunction:file:lineNumber:description:] + 165
	4   Firestore_Example_iOS               0x00000001026d7457 _ZN8firebase9firestore4util8internal4FailEPKcS4_iRKNSt3__112basic_stringIcNS5_11char_traitsIcEENS5_9allocatorIcEEEE + 1655
	5   Firestore_Example_iOS               0x00000001026d8609 _ZN8firebase9firestore4util8internal4FailEPKcS4_iRKNSt3__112basic_stringIcNS5_11char_traitsIcEENS5_9allocatorIcEEEES4_ + 4249
	6   Firestore_Example_iOS               0x00000001023abe18 _ZZ30-[FSTLocalStore releaseQuery:]ENK4$_12clEv + 1128
	7   Firestore_Example_iOS               0x0000000102392171 _ZNK20FSTTransactionRunnerclIZ30-[FSTLocalStore releaseQuery:]E4$_12EENSt3__19enable_ifIXsr3std7is_voidIDTclfp0_EEEE5valueEvE4typeEN4absl11string_viewET_ + 1457
	8   Firestore_Example_iOS               0x0000000102391a36 -[FSTLocalStore releaseQuery:] + 1110
	9   Firestore_Example_iOS               0x00000001025e0ba4 -[FSTSyncEngine stopListeningToQuery:] + 1460
	10  Firestore_Example_iOS               0x000000010222ead2 -[FSTEventManager removeListener:] + 2354
	11  Firestore_Example_iOS               0x000000010225fab0 __37-[FSTFirestoreClient removeListener:]_block_invoke + 304
	12  Firestore_Example_iOS               0x00000001021f7c22 _ZZ34-[FSTDispatchQueue dispatchAsync:]ENK3$_1clEv + 146
	13  Firestore_Example_iOS               0x00000001021f7b85 _ZNSt3__128__invoke_void_return_wrapperIvE6__callIJRZ34-[FSTDispatchQueue dispatchAsync:]E3$_1EEEvDpOT_ + 117
	14  Firestore_Example_iOS               0x00000001021f774f _ZNSt3__110__function6__funcIZ34-[FSTDispatchQueue dispatchAsync:]E3$_1NS_9allocatorIS2_EEFvvEEclEv + 95
	15  Firestore_Example_iOS               0x0000000101f70b77 _ZNKSt3__18functionIFvvEEclEv + 391
	16  Firestore_Example_iOS               0x0000000101f704b9 _ZN8firebase9firestore4util10AsyncQueue15ExecuteBlockingERKNSt3__18functionIFvvEEE + 1305
	17  Firestore_Example_iOS               0x0000000101f7b1ff _ZZN8firebase9firestore4util10AsyncQueue4WrapERKNSt3__18functionIFvvEEEENK3$_0clEv + 95
	18  Firestore_Example_iOS               0x0000000101f7b195 _ZNSt3__128__invoke_void_return_wrapperIvE6__callIJRZN8firebase9firestore4util10AsyncQueue4WrapERKNS_8functionIFvvEEEE3$_0EEEvDpOT_ + 117
	19  Firestore_Example_iOS               0x0000000101f7ac9f _ZNSt3__110__function6__funcIZN8firebase9firestore4util10AsyncQueue4WrapERKNS_8functionIFvvEEEE3$_0NS_9allocatorISB_EES7_EclEv + 95
	20  Firestore_Example_iOS               0x0000000101f70b77 _ZNKSt3__18functionIFvvEEclEv + 391
	21  Firestore_Example_iOS               0x0000000101fc1cd3 _ZZN8firebase9firestore4util8internal13DispatchAsyncEPU28objcproto17OS_dispatch_queue8NSObjectONSt3__18functionIFvvEEEENK3$_0clEPv + 51
	22  Firestore_Example_iOS               0x0000000101fc1c98 _ZZN8firebase9firestore4util8internal13DispatchAsyncEPU28objcproto17OS_dispatch_queue8NSObjectONSt3__18functionIFvvEEEEN3$_08__invokeEPv + 24
	23  libclang_rt.asan_iossim_dynamic.dylib 0x0000000103722ca3 asan_dispatch_call_block_and_release + 323
	24  libdispatch.dylib                   0x000000010ab06779 _dispatch_client_callout + 8
	25  libdispatch.dylib                   0x000000010ab0e1b2 _dispatch_queue_serial_drain + 735
	26  libdispatch.dylib                   0x000000010ab0e9af _dispatch_queue_invoke + 321
	27  libdispatch.dylib                   0x000000010ab0b16a _dispatch_queue_override_invoke + 477
	28  libdispatch.dylib                   0x000000010ab10cf8 _dispatch_root_queue_drain + 473
	29  libdispatch.dylib                   0x000000010ab10ac1 _dispatch_worker_thread3 + 119
	30  libsystem_pthread.dylib             0x000000010b029169 _pthread_wqthread + 1387
	31  libsystem_pthread.dylib             0x000000010b028be9 start_wqthread + 13
)
libc++abi.dylib: terminating with uncaught exception of type NSException
==12899== ERROR: libFuzzer: deadly signal
    #0 0x10372da47 in __sanitizer_print_stack_trace (libclang_rt.asan_iossim_dynamic.dylib:x86_64+0x5da47)
    #1 0x1253a6fc3 in fuzzer::PrintStackTrace() FuzzerUtil.cpp:206
    #2 0x125201863 in fuzzer::Fuzzer::CrashCallback() FuzzerLoop.cpp:233
    #3 0x12520172b in fuzzer::Fuzzer::StaticCrashSignalCallback() FuzzerLoop.cpp:205
    #4 0x1253ac879 in fuzzer::CrashHandler(int, __siginfo*, void*) FuzzerUtilPosix.cpp:36
    #5 0x10b017f59 in _sigtramp (libsystem_platform.dylib:x86_64+0x1f59)
    #6 0x10b03630a  (libsystem_pthread.dylib):x86_64+0x1030a)
    #7 0x10ac4dc96 in abort (libsystem_c.dylib:x86_64+0x5bc96)
    #8 0x10a9e3e6e in abort_message (libc++abi.dylib:x86_64+0x1e6e)
    #9 0x10a9e400a in default_terminate_handler() (libc++abi.dylib:x86_64+0x200a)
    #10 0x1099e82ad in _objc_terminate() (libobjc.A.dylib:x86_64+0x52ad)
    #11 0x10aa010ad in std::__terminate(void (*)()) (libc++abi.dylib:x86_64+0x1f0ad)
    #12 0x10aa01122 in std::terminate() (libc++abi.dylib:x86_64+0x1f122)
    #13 0x10ab0678c in _dispatch_client_callout (libdispatch.dylib:x86_64+0x378c)
    #14 0x10ab0e1b1 in _dispatch_queue_serial_drain (libdispatch.dylib:x86_64+0xb1b1)
    #15 0x10ab0e9ae in _dispatch_queue_invoke (libdispatch.dylib:x86_64+0xb9ae)
    #16 0x10ab0b169 in _dispatch_queue_override_invoke (libdispatch.dylib:x86_64+0x8169)
    #17 0x10ab10cf7 in _dispatch_root_queue_drain (libdispatch.dylib:x86_64+0xdcf7)
    #18 0x10ab10ac0 in _dispatch_worker_thread3 (libdispatch.dylib:x86_64+0xdac0)
    #19 0x10b029168 in _pthread_wqthread (libsystem_pthread.dylib:x86_64+0x3168)
    #20 0x10b028be8 in start_wqthread (libsystem_pthread.dylib:x86_64+0x2be8)

NOTE: libFuzzer has rudimentary signal handlers.
      Combine libFuzzer with AddressSanitizer or similar for better crash reports.
SUMMARY: libFuzzer: deadly signal
MS: 0 ; base unit: 0000000000000000000000000000000000000000
0x0,0x4d,0x49,0x4e,0x41,
\x00MINA
artifact_prefix='/tmp/'; Test unit written to /tmp/crash-ec57127cfb761f4fc112400f6aa61080ad638ad6
Base64: AE1JTkE=
stat::number_of_executed_units: 11
stat::average_exec_per_sec:     0
stat::new_units_added:          0
stat::slowest_unit_time_sec:    10
stat::peak_rss_mb:              258
2018-07-05 10:10:21.148 xcodebuild[12575:113735] Error Domain=IDETestOperationsObserverErrorDomain Code=6 "Early unexpected exit, operation never finished bootstrapping - no restart will be attempted" UserInfo={NSLocalizedDescription=Early unexpected exit, operation never finished bootstrapping - no restart will be attempted}
Generating coverage data...

