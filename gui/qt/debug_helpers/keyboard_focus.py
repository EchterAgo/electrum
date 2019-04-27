"""
This helper allows you to more easily see where the current keyboard focus is in the Qt Gui. The
element with keyboard focus will get a green border and a red background. This will not work on
every widget, but it still helps. On change of keyboard focus there will also be a printed message
that shows the type and window title of the newly focused widget.

To use it, just call the trace function of the module from anywhere.
"""

from PyQt5 import QtWidgets

from electroncash.util import print_error

def trace():
    """
    Enables visual keyboard focus tracing
    """
    app = QtWidgets.QApplication.instance()
    app.focusChanged.connect(log)
    style_sheet = app.styleSheet()
    style_sheet = style_sheet + '''
    QWidget:focus {
        border: 2px solid green;
        background: red;
    }
    '''
    app.setStyleSheet(style_sheet)

def log(old: QtWidgets.QWidget, new: QtWidgets.QWidget):
    """
    Logs a change of focus to the verbose console
    """
    if new:
        print_error('Focus to {} "{}"'.format(type(new), new.windowTitle()))
