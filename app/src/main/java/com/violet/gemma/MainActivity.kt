package com.violet.gemma

import android.graphics.Color
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.lifecycle.viewmodel.compose.viewModel
import com.violet.gemma.ui.AuroraBackground
import com.violet.gemma.ui.ChatScreen
import com.violet.gemma.ui.ChatViewModel
import com.violet.gemma.ui.LoadingScreen
import com.violet.gemma.ui.Phase
import com.violet.gemma.ui.SetupScreen
import com.violet.gemma.ui.theme.VioletTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge(
            statusBarStyle = SystemBarStyle.dark(Color.TRANSPARENT),
            navigationBarStyle = SystemBarStyle.dark(Color.TRANSPARENT),
        )
        setContent {
            VioletTheme {
                val vm: ChatViewModel = viewModel()
                AppRoot(vm)
            }
        }
    }
}

@Composable
private fun AppRoot(vm: ChatViewModel) {
    Box(Modifier.fillMaxSize()) {
        AuroraBackground()
        AnimatedContent(
            targetState = vm.phase,
            transitionSpec = {
                (fadeIn(tween(600)) + scaleIn(tween(600), initialScale = 0.96f)) togetherWith fadeOut(tween(300))
            },
            label = "phase",
        ) { p ->
            when (p) {
                Phase.SETUP -> SetupScreen(vm)
                Phase.LOADING -> LoadingScreen(vm)
                Phase.READY -> ChatScreen(vm)
            }
        }
    }
}
