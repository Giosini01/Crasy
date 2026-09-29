# Stripe: il pannello di pagamento usa classi che R8 altrimenti toglierebbe
# dalla build di release. Regole dalla documentazione di flutter_stripe.
-dontwarn com.stripe.android.pushProvisioning.**
-dontwarn com.google.android.gms.tapandpay.**
-dontwarn kotlinx.parcelize.Parceler$DefaultImpls
-dontwarn kotlinx.parcelize.Parceler
-dontwarn kotlinx.parcelize.Parcelize
-keep class com.stripe.** { *; }
