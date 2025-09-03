package com.blynt.india

import io.flutter.embedding.android.FlutterActivity
import androidx.multidex.MultiDex  // FIXED: Correct import (was MultiDx)
import android.content.Context

class MainActivity : FlutterActivity() {
    override fun attachBaseContext(base: Context) {
        super.attachBaseContext(base)
        MultiDex.install(this)  // FIXED: Correct class name (was MultiDx)
    }
}