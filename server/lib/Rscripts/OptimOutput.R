Rlog <- readLines('/var/www/rails/openstudio/log/Rserve.log')
Iteration <- length(Rlog[grep('Iteration',Rlog)]) - 1
Iteration
Rlog[grep('L =',Rlog)]
Rlog[grep('X0 =',Rlog)]
Rlog[grep('U =',Rlog)]
Xlog <- Rlog[grep('X =',Rlog)]
Xlog[-grep('Cauchy',Xlog)]
Rlog[grep('norm of step',Rlog)]
Rlog[grep('Objective function Norm',Rlog)]
