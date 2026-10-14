package com.example.storagemonitor.viewmodel

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.storagemonitor.model.Alert
import com.example.storagemonitor.model.StatusResponse
import com.example.storagemonitor.network.RetrofitClient
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

class DashboardViewModel : ViewModel() {

    var status by mutableStateOf<StatusResponse?>(null)
        private set

    var alerts by mutableStateOf<List<Alert>>(emptyList())
        private set

    var isLoading by mutableStateOf(true)
        private set

    var errorMessage by mutableStateOf<String?>(null)
        private set

    init {
        startPolling()
    }

    private fun startPolling() {
        viewModelScope.launch {
            while (true) {
                refresh()
                delay(5000)
            }
        }
    }

    private suspend fun refresh() {
        try {
            status = RetrofitClient.api.getStatus()
            alerts = RetrofitClient.api.getAlerts()
            errorMessage = null
        } catch (e: Exception) {
            errorMessage = "Can't reach the backend - is `node server.js` running? (${e.message})"
        } finally {
            isLoading = false
        }
    }
}
