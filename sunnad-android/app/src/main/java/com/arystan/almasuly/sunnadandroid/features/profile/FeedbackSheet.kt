package com.arystan.almasuly.sunnadandroid.features.profile

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.Error
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TextField
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.arystan.almasuly.sunnadandroid.R
import com.arystan.almasuly.sunnadandroid.ui.components.PrimaryPillButton
import com.arystan.almasuly.sunnadandroid.ui.components.SunnadCard
import kotlinx.coroutines.delay

private data class FeedbackToast(
    val message: String,
    val isError: Boolean
)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FeedbackSheet(
    onDismiss: () -> Unit
) {
    var text by remember { mutableStateOf("") }
    var isSending by remember { mutableStateOf(false) }
    var sendAttempt by remember { mutableStateOf(0) }
    var toast by remember { mutableStateOf<FeedbackToast?>(null) }
    val failedMessage = stringResource(R.string.feedback_failed)
    val sentMessage = stringResource(R.string.feedback_sent)

    LaunchedEffect(toast) {
        if (toast != null) {
            delay(1800)
            toast = null
        }
    }

    ModalBottomSheet(onDismissRequest = onDismiss) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = stringResource(R.string.profile_send_feedback),
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.SemiBold,
                    modifier = Modifier.weight(1f)
                )
                TextButton(onClick = onDismiss) {
                    Icon(
                        imageVector = Icons.Rounded.Close,
                        contentDescription = null
                    )
                }
            }

            toast?.let { info ->
                SunnadCard {
                    Row(
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Icon(
                            imageVector = if (info.isError) Icons.Rounded.Error else Icons.Rounded.Check,
                            contentDescription = null,
                            tint = if (info.isError) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.primary
                        )
                        Text(
                            text = info.message,
                            style = MaterialTheme.typography.bodyMedium
                        )
                    }
                }
            }

            SunnadCard {
                TextField(
                    value = text,
                    onValueChange = { text = it },
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(170.dp),
                    placeholder = { Text(stringResource(R.string.feedback_placeholder)) }
                )
            }

            PrimaryPillButton(
                title = if (isSending) stringResource(R.string.feedback_sending) else stringResource(R.string.feedback_send),
                enabled = !isSending && text.trim().isNotEmpty(),
                onClick = {
                    isSending = true
                    sendAttempt += 1
                }
            )

            if (isSending) {
                LaunchedEffect(sendAttempt) {
                    delay(700)
                    isSending = false
                    if (sendAttempt % 4 == 0) {
                        toast = FeedbackToast(
                            message = failedMessage,
                            isError = true
                        )
                    } else {
                        toast = FeedbackToast(
                            message = sentMessage,
                            isError = false
                        )
                        delay(650)
                        onDismiss()
                    }
                }
            }

            androidx.compose.foundation.layout.Spacer(modifier = Modifier.height(10.dp))
        }
    }
}
