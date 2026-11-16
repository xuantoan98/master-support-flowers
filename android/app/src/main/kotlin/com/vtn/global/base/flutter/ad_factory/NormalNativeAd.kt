package com.vtn.global.base.flutter.ad_factory

import android.content.Context
import android.view.LayoutInflater
import android.view.View
import android.widget.LinearLayout
import android.widget.Button
import android.widget.ImageView
import android.widget.TextView
import com.google.android.gms.ads.nativead.MediaView
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView
import com.vtn.global.base.flutter.R
import com.vtn.global.base.flutter.enum.ButtonPosition
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.view.ViewGroup
import com.bumptech.glide.Glide
import androidx.core.net.toUri
import com.vtn.global.base.flutter.CachedAdData
import com.vtn.global.base.flutter.CachedAdNativeAdFactory

class NormalNativeAd(
    private val context: Context,
    private val buttonPosition: ButtonPosition = ButtonPosition.Bottom,
) :
    GoogleMobileAdsPlugin.NativeAdFactory, CachedAdNativeAdFactory {
    override fun createNativeAd(
        nativeAd: NativeAd,
        customOptions: MutableMap<String, Any>?
    ): NativeAdView {
        val adView =
            LayoutInflater.from(context)
                .inflate(R.layout.custom_normal_native_ad, null) as NativeAdView

        with(adView) {
            // Set the media view.
            val mediaView = findViewById<MediaView>(R.id.ad_media)
            setMediaView(mediaView)

            // Set other ad assets.
            val headlineView = findViewById<TextView>(R.id.ad_headline)
            setHeadlineView(headlineView)
            val bodyView = findViewById<TextView>(R.id.ad_body)
            setBodyView(bodyView)
            var buttonId: Int;
            if (buttonPosition == ButtonPosition.Bottom) {
                buttonId = R.id.ad_call_to_action_bottom;
                findViewById<Button>(R.id.ad_call_to_action).visibility = View.GONE
            } else {
                buttonId = R.id.ad_call_to_action;
                findViewById<Button>(R.id.ad_call_to_action_bottom).visibility = View.GONE
            }
            val callToActionView = findViewById<Button>(buttonId)
            setCallToActionView(callToActionView)
            val iconView = findViewById<ImageView>(R.id.ad_app_icon)
            setIconView(iconView)

            // The headline and mediaContent are guaranteed to be in every NativeAd.
            headlineView.text = nativeAd.headline
            advertiserView = findViewById<TextView>(R.id.adText)

            mediaView.mediaContent = nativeAd.mediaContent

            // These assets aren't guaranteed to be in every NativeAd, so it's important to
            // check before trying to display them.
            if (nativeAd.body == null) {
                bodyView.visibility = View.INVISIBLE
            } else {
                bodyView.text = nativeAd.body
            }
            if (nativeAd.callToAction == null) {
                callToActionView.visibility = View.INVISIBLE
            } else {
                callToActionView.text = nativeAd.callToAction
            }
            if (nativeAd.icon == null) {
                iconView.apply {
                    visibility = View.INVISIBLE
                    layoutParams = LinearLayout.LayoutParams(16, 16)
                }
            } else {
                iconView.setImageDrawable(nativeAd.icon!!.drawable)
            }

            setNativeAd(nativeAd)
        }
        return adView
    }

    override fun createCachedAd(context: Context, data: CachedAdData): View {
        val view = LayoutInflater.from(context)
            .inflate(R.layout.custom_normal_native_ad, null)

        view.findViewById<TextView>(R.id.ad_headline).text = data.headline
        view.findViewById<TextView>(R.id.ad_body)?.text = data.body

        val ctaId = if (buttonPosition == ButtonPosition.Bottom) {
            view.findViewById<Button>(R.id.ad_call_to_action).visibility = View.GONE
            R.id.ad_call_to_action_bottom
        } else {
            view.findViewById<Button>(R.id.ad_call_to_action_bottom).visibility = View.GONE
            R.id.ad_call_to_action
        }
        val cta = view.findViewById<Button>(ctaId)
        cta.text = data.callToAction
        cta.visibility = View.VISIBLE

        val iconView = view.findViewById<ImageView>(R.id.ad_app_icon)
        if (data.iconUrl.isNotEmpty()) {
            Glide.with(context).load(data.iconUrl).into(iconView)
        } else {
            iconView.visibility = View.INVISIBLE
        }

        val mediaView = view.findViewById<MediaView>(R.id.ad_media)
        mediaView.removeAllViews()
        if (data.featureImageUrl.isNotEmpty()) {
            val img = ImageView(context).apply {
                layoutParams = ViewGroup.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.MATCH_PARENT,
                )
                scaleType = ImageView.ScaleType.CENTER_CROP
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