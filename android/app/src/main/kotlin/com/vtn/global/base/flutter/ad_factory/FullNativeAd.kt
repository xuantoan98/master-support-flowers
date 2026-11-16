package com.vtn.global.base.flutter.ad_factory

import android.content.Context
import android.view.LayoutInflater
import android.view.View
import android.widget.Button
import android.widget.ImageView
import android.widget.TextView
import androidx.core.content.ContextCompat
import com.google.android.gms.ads.nativead.MediaView
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView
import com.vtn.global.base.flutter.R
import com.vtn.global.base.flutter.enum.ButtonPosition
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin.NativeAdFactory
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.view.ViewGroup
import com.bumptech.glide.Glide
import androidx.core.net.toUri
import com.vtn.global.base.flutter.CachedAdData
import com.vtn.global.base.flutter.CachedAdNativeAdFactory


class FullNativeAd(
    private val context: Context,
) :
    NativeAdFactory, CachedAdNativeAdFactory {
    override fun createNativeAd(
        nativeAd: NativeAd,
        customOptions: MutableMap<String, Any>?
    ): NativeAdView {
        val adView =
            LayoutInflater.from(context).inflate(R.layout.full_native_ad, null) as NativeAdView

        with(adView) {
            val headlineView = findViewById<TextView>(R.id.ad_headline)
            setHeadlineView(headlineView)
            val bodyView = findViewById<TextView>(R.id.ad_body)
            setBodyView(bodyView)
            val callToActionView = findViewById<Button>(R.id.bottom_ad_call_to_action)
            setCallToActionView(callToActionView)
            headlineView.text = nativeAd.headline

            val mediaView = findViewById<MediaView>(R.id.ad_media)
            setMediaView(mediaView)
            mediaView.mediaContent = nativeAd.mediaContent

            if (nativeAd.body == null) {
                bodyView.visibility = View.INVISIBLE
            } else {
                bodyView.visibility = View.VISIBLE
                bodyView.text = nativeAd.body
            }
            if (nativeAd.callToAction == null) {
                callToActionView.visibility = View.INVISIBLE
            } else {
                callToActionView.visibility = View.VISIBLE
                callToActionView.text = nativeAd.callToAction
            }


            setNativeAd(nativeAd)
        }
        return adView
    }

    override fun createCachedAd(context: Context, data: CachedAdData): View {
        val view = LayoutInflater.from(context)
            .inflate(R.layout.full_native_ad, null)

        view.findViewById<TextView>(R.id.ad_headline).text = data.headline
        view.findViewById<TextView>(R.id.ad_body)?.text = data.body


        val cta = view.findViewById<Button>(R.id.bottom_ad_call_to_action)
        cta.text = data.callToAction
        cta.visibility = View.VISIBLE


        val mediaView = view.findViewById<MediaView>(R.id.ad_media)
        mediaView.removeAllViews()
        if (data.featureImageUrl.isNotEmpty()) {
            val img = ImageView(context).apply {
                layoutParams = ViewGroup.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.MATCH_PARENT,
                )
                scaleType = ImageView.ScaleType.FIT_CENTER
                adjustViewBounds = true
            }
            Glide.with(context).load(data.featureImageUrl).into(img)
            mediaView.addView(img)
        }

        val onClick = View.OnClickListener {
            try {
                context.startActivity(
                    Intent(
                        Intent.ACTION_VIEW,
                        "https://play.google.com/store/apps/details?id=${data.packageName}".toUri(),
                    ).setFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                )
            } catch (_: ActivityNotFoundException) {

            }
        }
        view.setOnClickListener(onClick)
        cta.setOnClickListener(onClick)
        return view
    }
}
