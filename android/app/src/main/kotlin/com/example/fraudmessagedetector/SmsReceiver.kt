package com.example.fraudmessagedetector

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import com.shounakmulay.telephony.sms.IncomingSmsReceiver

class SmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context?, intent: Intent?) {
        if (context != null && intent != null) {
            val libraryReceiver = IncomingSmsReceiver()
            libraryReceiver.onReceive(context, intent)
        }
    }
}
