package com.example.tdmu_smartdocs;

import androidx.test.platform.app.InstrumentationRegistry;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.junit.runners.Parameterized;
import org.junit.runners.Parameterized.Parameters;
import pl.leancode.patrol.PatrolJUnitRunner;

/**
 * Entry point cho Patrol E2E integration tests.
 *
 * PatrolJUnitRunner lấy danh sách Dart test cases, mỗi case
 * trở thành 1 JUnit @Test parameterized — kết quả hiển thị
 * riêng từng test trong Android test report.
 *
 * Chạy: patrol test --target integration_test/app_test.dart
 */
@RunWith(Parameterized.class)
public class MainActivityTest {

    @Parameters(name = "{0}")
    public static Object[] testCases() {
        PatrolJUnitRunner instrumentation =
                (PatrolJUnitRunner) InstrumentationRegistry.getInstrumentation();
        instrumentation.setUp(MainActivity.class);
        instrumentation.waitForPatrolAppService();
        return instrumentation.listDartTests();
    }

    public MainActivityTest(String dartTestName) {
        this.dartTestName = dartTestName;
    }

    private final String dartTestName;

    @Test
    public void runDartTest() {
        PatrolJUnitRunner instrumentation =
                (PatrolJUnitRunner) InstrumentationRegistry.getInstrumentation();
        instrumentation.runDartTest(dartTestName);
    }
}
