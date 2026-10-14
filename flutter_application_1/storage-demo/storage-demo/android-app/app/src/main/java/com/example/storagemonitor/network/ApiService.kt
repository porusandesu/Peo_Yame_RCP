package com.example.storagemonitor.network

import com.example.storagemonitor.model.Alert
import com.example.storagemonitor.model.Reading
import com.example.storagemonitor.model.StatusResponse
import retrofit2.http.GET
import retrofit2.http.Query

interface ApiService {

    @GET("api/status")
    suspend fun getStatus(): StatusResponse

    @GET("api/readings/history")
    suspend fun getHistory(@Query("limit") limit: Int = 50): List<Reading>

    @GET("api/alerts")
    suspend fun getAlerts(): List<Alert>
}
