package com.example.bloom_cycle

import io.flutter.embedding.android.FlutterFragmentActivity

// local_auth requires the host Activity to be a FlutterFragmentActivity
// (it needs androidx Fragment support to show the system biometric prompt).
// Using plain FlutterActivity here was why biometric auth silently failed.
class MainActivity : FlutterFragmentActivity()
