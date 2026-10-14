package com.example.storagemonitor.network

import retrofit2.Retrofit
import retrofit2.converter.gson.GsonConverterFactory

object RetrofitClient {

    /**
     * IMPORTANT: point this at wherever `node server.js` is running.
     *
     * - Android EMULATOR -> your laptop's localhost is reached via 10.0.2.2
     *   (this is the default below, already correct for the emulator).
     * - PHYSICAL PHONE on the same WiFi -> replace with your laptop's LAN IP,
     *   e.g. "http://192.168.1.42:3000/" (find it with `ipconfig` / `ifconfig`,
     *   and make sure the phone and laptop are on the same network).
     */
    private const val BASE_URL = "http://10.0.2.2:3000/"

    val api: ApiService by lazy {
        Retrofit.Builder()
            .baseUrl(BASE_URL)
            .addConverterFactory(GsonConverterFactory.create())
            .build()
            .create(ApiService::class.java)
    }
}
