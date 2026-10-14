package com.example.storagemonitor.model

data class Reading(
    val id: Int,
    val temperature: Double,
    val humidity: Double,
    val recordedAt: String
)

data class Threshold(
    val commodity: String,
    val minTemp: Double,
    val maxTemp: Double,
    val minHumidity: Double,
    val maxHumidity: Double
)

data class StatusResponse(
    val latest: Reading?,
    val threshold: Threshold,
    val breached: Boolean
)

data class Alert(
    val id: Int,
    val readingId: Int,
    val message: String,
    val sentAt: String
)
