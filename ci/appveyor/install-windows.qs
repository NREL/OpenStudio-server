function Controller() {
    console.log("Controller created");
    // gui.setSilent(true); // cannot use until QtIFW v3.0.1, keep commented
}

Controller.prototype.IntroductionPageCallback = function () {
    console.log("IntroductionPageCallback");
    gui.clickButton(buttons.NextButton);
}

Controller.prototype.ComponentSelectionPageCallback = function () {
    console.log("ComponentSelectionPageCallback");
    var widget = gui.currentPageWidget();
    if (widget) {
        console.log("ComponentSelectionPage widget OK");
        // If you want defaults, do nothing else.
        // Example if you ever want to tweak:
        // widget.deselectAll();
        // widget.selectComponent("CLI");
    }
    gui.clickButton(buttons.NextButton);
}

Controller.prototype.TargetDirectoryPageCallback = function () {
    console.log("TargetDirectoryPageCallback");
    var widget = gui.currentPageWidget();
    if (widget && widget.TargetDirectoryLineEdit) {
        widget.TargetDirectoryLineEdit.setText("c:\\openstudio");
        console.log("Set target directory to c:\\openstudio");
    } else {
        console.log("TargetDirectoryLineEdit not found on this page");
    }
    gui.clickButton(buttons.NextButton);
}

Controller.prototype.StartMenuDirectoryPageCallback = function () {
    console.log("StartMenuDirectoryPageCallback");
    gui.clickButton(buttons.NextButton);
}

Controller.prototype.ReadyForInstallationPageCallback = function () {
    console.log("ReadyForInstallationPageCallback");
    gui.clickButton(buttons.NextButton);
}

Controller.prototype.FinishedPageCallback = function () {
    console.log("FinishedPageCallback");
    gui.clickButton(buttons.FinishButton);
}
