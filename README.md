# DivergenceMeter

This is code for [Tom Titor's divergence meter](http://www.mindspring.com/~tomtitor/index.html).

The main change is that the worldline displays will automatically move on to the next worldline after around 9 seconds, unless the user presses button 1 and moves it on manually. This allows you to put the clock into a 'worldline mode' and not have to keep pressing buttons to change the display. This is explained below.

The other change is that it will display a random worldline for 9 secconds twice an hour. You can go straight back to clock mode by pressing button 1. The display uses the 'rolling' animation to display the worldline (I like this animation!).

## Clock Display Mode
**Short Press Button 1** will display a random worldline. Note this is a change - in 1.05 the first worldline it displays is always the same one. It also animates to the worldline rather than just switching the display.

All other button presses in this mode are the same as in 1.05.
## Random Worldline Mode
**Short Press Button 1** will display another random worldline.

**9 Second Timeout** is like pressing button 1 - it will display another random worldline.

**Long Press Button 1** will display worldlines from the anime and visual novel

**Press Button 2** will go to the clock display
## Fixed Worldline Mode
**Short Press Button 1** will display the next worldline.

**9 Second Timeout** is like pressing button 1 - it will display the next worldline.
When the last world line is displayed, the display will revert to Random Worldline Mode.

**Long Press Button 1** will move into User Worldline mode. Note that this is different from Tom's code, where it will take you to clock mode. I felt this was a more consistent use of Button 1.

**Press Button 2** will revert to clock mode. Note that this is different from Tom's code, where it will take you to User Worldline mode. I felt this was a more consistent use of Button 2.
## User Worldline Mode
Enter a worldline like in Tom Titor's version. When the last digit is entered it will enter a mode like **Random Worldline** mode, except that every second number will be the user's number.

**Short Press Button 1** will move to the next number/the user's number

**9 Second Timeout** is like pressing button 1

**Long Press Button 1** will move back to Random Worldline mode

**Press Button 2** will move to clock mode

