package com.example.tdmu_smartdocs

import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.runner.RunWith
import pl.leancode.patrol.PatrolJUnitRunner

/**
 * Entry point cho Patrol integration tests.
 *
 * PatrolJUnitRunner chạy tất cả test được định nghĩa trong
 * integration_test/ thông qua Android Instrumentation.
 *
 * Chạy: patrol test --target integration_test/app_test.dart
 */
@RunWith(PatrolJUnitRunner::class)
class MainActivityTest
