package com.arystan.almasuly.sunnadandroid.app

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider

class SunnadViewModelFactory<VM : ViewModel>(
    private val create: () -> VM
) : ViewModelProvider.Factory {
    @Suppress("UNCHECKED_CAST")
    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        return create() as T
    }
}
