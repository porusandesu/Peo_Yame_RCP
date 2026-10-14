package com.example.storagemonitor.ui

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.example.storagemonitor.model.Alert
import com.example.storagemonitor.model.StatusResponse
import com.example.storagemonitor.viewmodel.DashboardViewModel

@Composable
fun DashboardScreen(viewModel: DashboardViewModel) {
    Scaffold(
        topBar = {
            TopAppBar(title = { Text("Storage Monitor") })
        }
    ) { padding ->
        Column(
            modifier = Modifier
                .padding(padding)
                .padding(16.dp)
                .fillMaxSize()
        ) {
            viewModel.errorMessage?.let { msg ->
                Card(
                    colors = CardDefaults.cardColors(containerColor = Color(0xFFFFEBEE)),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Text(msg, modifier = Modifier.padding(12.dp))
                }
                Spacer(Modifier.height(16.dp))
            }

            if (viewModel.isLoading && viewModel.status == null) {
                Box(Modifier.fillMaxWidth().padding(32.dp), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator()
                }
            }

            viewModel.status?.let { StatusCard(it) }

            Spacer(Modifier.height(24.dp))
            Text("Recent Alerts", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
            Spacer(Modifier.height(8.dp))

            if (viewModel.alerts.isEmpty()) {
                Text("No alerts yet.", color = Color.Gray)
            } else {
                LazyColumn {
                    items(viewModel.alerts) { alert -> AlertRow(alert) }
                }
            }
        }
    }
}

@Composable
fun StatusCard(status: StatusResponse) {
    val breached = status.breached
    Card(
        colors = CardDefaults.cardColors(
            containerColor = if (breached) Color(0xFFFFCDD2) else Color(0xFFE8F5E9)
        ),
        modifier = Modifier.fillMaxWidth()
    ) {
        Column(Modifier.padding(16.dp)) {
            Text(
                if (breached) "⚠ Threshold breached" else "✓ Conditions normal",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold
            )
            Spacer(Modifier.height(8.dp))
            status.latest?.let { r ->
                Text("Temperature: ${r.temperature}°C")
                Text("Humidity: ${r.humidity}%")
                Text("Recorded: ${r.recordedAt}", color = Color.Gray, style = MaterialTheme.typography.bodySmall)
            }
            Spacer(Modifier.height(8.dp))
            Text(
                "Safe range for ${status.threshold.commodity}: " +
                    "${status.threshold.minTemp}-${status.threshold.maxTemp}°C, " +
                    "${status.threshold.minHumidity}-${status.threshold.maxHumidity}% RH",
                style = MaterialTheme.typography.bodySmall,
                color = Color.Gray
            )
        }
    }
}

@Composable
fun AlertRow(alert: Alert) {
    Card(modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp)) {
        Column(Modifier.padding(12.dp)) {
            Text(alert.message, fontWeight = FontWeight.Bold)
            Text(alert.sentAt, style = MaterialTheme.typography.bodySmall, color = Color.Gray)
        }
    }
}
