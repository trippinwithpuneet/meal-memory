import XCTest

/// UX evals — the flows a first-time user actually walks, driven on a real
/// simulator against the shipping UI.
///
/// These run entirely in demo mode (`-demo_mode_active YES`), which is offline
/// by design, so they never touch Supabase and are immune to the iOS 26.5
/// simulator QUIC issues documented in CLAUDE.md.
///
/// What they grade is reachability and state, not pixels: can a new user see
/// the week, move between the four tabs, find the primary action, and get to
/// Fridge Raid — without anything dead-ending.
final class DemoFlowUITests: XCTestCase {

    private var app: XCUIApplication!
    private let timeout: TimeInterval = 10

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // Force the explore-first demo state regardless of what a previous run left behind.
        app.launchArguments += ["-demo_mode_active", "YES"]
        app.launch()
    }

    // MARK: - First launch

    func testFirstLaunchOpensStraightIntoThePlanWithSampleData() {
        // The explore-first decision: no auth wall before the user sees value.
        XCTAssertTrue(
            app.staticTexts["You're exploring a sample week"].waitForExistence(timeout: timeout),
            "First launch must land on the sample week, not a sign-in screen"
        )
        XCTAssertTrue(app.staticTexts["Your data stays private when you sign up."].exists)
    }

    func testDemoBannerOffersAWayToStartForReal() {
        // The entire banner is one Button (the "Make it yours" pill is just part
        // of its label), so match on the label rather than a standalone button.
        // Side note for a11y: because the three Texts aren't wrapped in an
        // accessibilityElement(children: .combine) with an explicit label,
        // VoiceOver reads the whole banner as one run-on string.
        let banner = app.buttons.containing(
            NSPredicate(format: "label CONTAINS[c] %@", "Make it yours")
        ).firstMatch

        XCTAssertTrue(banner.waitForExistence(timeout: timeout),
                      "The demo must always offer a route into a real account")
        XCTAssertTrue(banner.isHittable)
        XCTAssertGreaterThanOrEqual(banner.frame.height, 44,
                                    "The demo CTA is below the 44pt minimum touch target")
        // Not tapped on purpose — leaving demo mode would make this run stateful.
    }

    func testSampleWeekActuallyShowsPlannedMeals() {
        // A demo with an empty grid teaches the user nothing.
        XCTAssertTrue(app.staticTexts["You're exploring a sample week"].waitForExistence(timeout: timeout))

        let knownDemoDishes = ["Egg Sandwich", "Burrito Bowl", "Tuna & Egg Salad", "Sheet-Pan Chicken & Veg"]
        let anyVisible = knownDemoDishes.contains { app.staticTexts[$0].exists }
        XCTAssertTrue(anyVisible, "Expected at least one demo dish on the week grid")
    }

    // MARK: - Navigation

    func testAllFourTabsExistAndAreReachable() {
        let tabs = ["Plan", "Recipes", "Shop", "Household"]
        for tab in tabs {
            let button = app.tabBars.buttons[tab]
            XCTAssertTrue(button.waitForExistence(timeout: timeout), "Missing tab: \(tab)")
            button.tap()
            XCTAssertTrue(button.isSelected, "Tapping \(tab) did not select it")
        }
    }

    func testRecipesTabListsTheDemoRecipeBank() {
        app.tabBars.buttons["Recipes"].tap()
        XCTAssertTrue(app.navigationBars["Recipes"].waitForExistence(timeout: timeout))

        let knownDemoRecipes = ["Burrito Bowl", "Tofu Stir Fry", "Pancakes", "Egg Sandwich"]
        let found = knownDemoRecipes.filter { app.staticTexts[$0].exists }
        XCTAssertFalse(found.isEmpty, "Recipe bank showed no demo recipes")
    }

    func testShopTabBuildsAGroceryListFromThePlannedWeek() {
        app.tabBars.buttons["Shop"].tap()
        XCTAssertTrue(app.staticTexts["Groceries"].waitForExistence(timeout: timeout))

        // With a pre-planned demo week the list must not be the empty state.
        XCTAssertFalse(app.staticTexts["Nothing to buy yet"].exists,
                       "Demo week has meals planned, so the grocery list should be populated")
    }

    func testHouseholdTabShowsTheDemoMembers() {
        app.tabBars.buttons["Household"].tap()
        let alex = app.staticTexts["Alex"]
        let jordan = app.staticTexts["Jordan"]
        XCTAssertTrue(alex.waitForExistence(timeout: timeout) || jordan.waitForExistence(timeout: 2),
                      "Household tab should list the demo members")
    }

    // MARK: - Primary action

    func testFridgeRaidIsReachableFromThePlanInOneTap() {
        // "What can I cook?" is the solo hero CTA — the single most important
        // button in the app. One tap from launch, and it must open Fridge Raid.
        let hero = app.buttons["What can I cook?"]
        XCTAssertTrue(hero.waitForExistence(timeout: timeout), "Primary CTA missing from the Plan tab")
        hero.tap()

        XCTAssertTrue(app.staticTexts["Fridge Raid"].waitForExistence(timeout: timeout),
                      "Primary CTA did not open Fridge Raid")
        XCTAssertTrue(app.staticTexts["What's in your fridge right now?"].exists)
    }

    func testPrimaryCTAMeetsTheMinimumTouchTarget() {
        // 44×44pt is Apple's floor; the base device for this project is the
        // iPhone 13 mini, where a cramped CTA shows up first.
        let hero = app.buttons["What can I cook?"]
        XCTAssertTrue(hero.waitForExistence(timeout: timeout))
        XCTAssertGreaterThanOrEqual(hero.frame.height, 44,
                                    "Primary CTA is below the 44pt minimum touch target")
    }

    func testTabBarButtonsMeetTheMinimumTouchTarget() {
        for tab in ["Plan", "Recipes", "Shop", "Household"] {
            let button = app.tabBars.buttons[tab]
            XCTAssertTrue(button.waitForExistence(timeout: timeout))
            XCTAssertGreaterThanOrEqual(button.frame.height, 44, "\(tab) tab is under 44pt tall")
        }
    }

    // MARK: - No dead ends

    func testEverySheetCanBeDismissed() {
        // A sheet you can't close is the worst kind of dead end. Fridge Raid is
        // the deepest modal reachable from a cold launch.
        let hero = app.buttons["What can I cook?"]
        XCTAssertTrue(hero.waitForExistence(timeout: timeout))
        hero.tap()
        XCTAssertTrue(app.staticTexts["Fridge Raid"].waitForExistence(timeout: timeout))

        // Swipe the sheet down to dismiss, then confirm we're back on the plan.
        app.swipeDown(velocity: .fast)
        XCTAssertTrue(app.buttons["What can I cook?"].waitForExistence(timeout: timeout),
                      "Could not get back to the Plan tab after opening Fridge Raid")
    }

    func testAppSurvivesRapidTabSwitching() {
        // Guards the iOS 26 `.sheet(item:)` fragility noted in CLAUDE.md.
        for _ in 0..<3 {
            for tab in ["Recipes", "Shop", "Household", "Plan"] {
                app.tabBars.buttons[tab].tap()
            }
        }
        XCTAssertEqual(app.state, .runningForeground, "App left the foreground during tab switching")
        XCTAssertTrue(app.tabBars.buttons["Plan"].isSelected)
    }

    // MARK: - Performance

    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            let fresh = XCUIApplication()
            fresh.launchArguments += ["-demo_mode_active", "YES"]
            fresh.launch()
        }
    }
}
