# Set working directory. This needs to be changed according to your file system
setwd("C:/dsge/r6/")

# Check if required packages have been installed. If not, they will be
# installed automatically.
packages <- c("foreach","doParallel")
if (length(setdiff(packages, rownames(installed.packages()))) > 0) {
  install.packages(setdiff(packages, rownames(installed.packages())))  
}
library(foreach)
library(doParallel)

# Set if you want to use parallel computing
# Note that you may not be able to reproduce simulated results using
# parallel computing
parallel_compute <- TRUE

################################################################
# Simulated Macroeconomic Factors based on the DSGE Model ######
################################################################

start_time <- Sys.time()

#DSGE exogeneous variable names
exo_vars <- c("eps_c", 
"eps_i",
"eps_g",
"eps_r",
"eps_a",
"eps_z",
"eps_H",
"eps_pi_cbar",
"eps_x",
"eps_d",
"eps_mc",
"eps_mi",
"eps_z_tildestar",
"eps_mu_z",
"eps_Rstar",
"eps_pistar",
"eps_ystar",
"eps_i_k",
"eps_i_y",
"me_w",
"me_E",
"me_pi_d",
"me_pi_i",
"me_y",
"me_c",
"me_i",
"me_imp",
"me_ex",
"me_ystar")

#DSGE endogeneous variable names in declaration order
endo_vars <- c("y",
"c",
"i",
"g",
"imp",
"ex",
"q",
"c_m",
"i_m",
"i_d",
"pi_cbar",
"pi_c",
"pi_i",
"pi_d",
"pi_mc",
"pi_mi",
"pi_x",
"mc_d",
"mc_mc",
"mc_mi",
"mc_x",
"r_k",
"w",
"P_k",
"mu_z",
"kbar",
"k",
"u",
"dS",
"x",
"R",
"a",
"psi_z",
"H",
"E",
"gamma_mcd",
"gamma_mid",
"gamma_xstar",
"gamma_cd",
"gamma_id",
"gamma_f",
"R_star",
"pi_star",
"y_star",
"e_ystar",
"e_pistar",
"e_c",
"e_i",
"e_a",
"e_z",
"e_H",
"lambda_x",
"lambda_d",
"lambda_mc",
"lambda_mi",
"z_tildestar",
"i_k",
"i_c",
"i_y",
"i_w",
"R_",
"pi_c_",
"pi_cbar_",
"pi_i_",
"pi_d_",
"dy_",
"dc_",
"di_",
"dimp_",
"dex_",
"dy_star_",
"pi_star_",
"R_star_",
"dE_",
"dS_",
"dw_",
"AUX_ENDO_LAG_25_1")

#DSGE endogeneous variable names in calculation order. It is needed because we need to group state variables
dr_orders <- c("imp",
"ex",
"q",
"c_m",
"i_m",
"i_d",
"pi_i",
"mc_d",
"mc_mc",
"mc_mi",
"u",
"H",
"gamma_cd",
"gamma_id",
"gamma_f",
"i_c",
"i_y",
"i_w",
"R_",
"pi_c_",
"pi_cbar_",
"pi_i_",
"pi_d_",
"dy_",
"dc_",
"di_",
"dimp_",
"dex_",
"dy_star_",
"pi_star_",
"R_star_",
"dE_",
"dS_",
"dw_",
"y",
"g",
"pi_cbar",
"pi_c",
"mc_x",
"kbar",
"k",
"x",
"R",
"a",
"gamma_mcd",
"gamma_mid",
"gamma_xstar",
"R_star",
"e_ystar",
"e_pistar",
"e_i",
"e_a",
"e_z",
"e_H",
"lambda_x",
"lambda_d",
"lambda_mc",
"lambda_mi",
"z_tildestar",
"AUX_ENDO_LAG_25_1",
"c",
"i",
"pi_d",
"pi_mc",
"pi_mi",
"pi_x",
"w",
"mu_z",
"E",
"y_star",
"e_c",
"i_k",
"r_k",
"P_k",
"dS",
"psi_z",
"pi_star")


#import the first order approximation of the calibrated DSGE model
dsge <- read.csv("input/dsge_foa.csv",header = TRUE)
#import the shocks in the calibrated DSGE model
dsge_shocks <- read.csv("input/dsge_shocks.csv",header = TRUE)

nperiod <- 120 #number of quarters to simulate
nsims <- 1000 #number of simulations
results <- matrix(0,nrow=nperiod*nsims,ncol=length(endo_vars))

steady_s <- dsge$y_s #get steady state
A <- dsge[,4:(length(endo_vars)+3)] #get matrix A for endogeneous variables
B <- dsge[,(length(endo_vars)+4):ncol(dsge)] #get matrix B for exogeneous variables

#generate scenarios based on the DSGE model
#the run speed is fast and therefore no parallel computing is built for this part.
set.seed(6)
counter <- 1
for (isim in c(1:nsims)){
	scn <- as.matrix(dsge$last_y)
	steady <- as.matrix(dsge$y_s)
	for (iperiod in c(1:nperiod)){
		shocks <- as.matrix(sapply(dsge_shocks$sigma, function(x) rnorm(1,0,x)))
		scn <- steady + as.matrix(A) %*% (scn-steady) + as.matrix(B) %*%  shocks
		results[counter,] <- scn
		counter <- counter + 1
	}
	if (isim %% 10 == 0){
		print(paste0("scenario ",isim," has been generated"))
	}
}

# Select the factors used for multifactor regression
colnames(results) <- dr_orders
keeps <- c("R_",
"pi_c_",
"pi_cbar_",
"pi_i_",
"pi_d_",
"dy_",
"dc_",
"di_",
"dimp_",
"dex_",
"dy_star_",
"pi_star_",
"R_star_",
"dE_",
"dS_",
"dw_"
)

results <- results[,colnames(results) %in% keeps]
results <- as.data.frame(results)
results$quarter <- rep(c(1:nperiod),nsims)

end_time <- Sys.time()
print(paste0("It took ", end_time - start_time, "mins to generate ", nsims, " economic factor scenarios of ", nperiod, " quarters."))

#produce results in Table 4
apply(results,2,mean)
apply(results,2,sd)

################################################################
# Simulated asset returns based on the multifactor model #######
################################################################

start_time <- Sys.time()

# read multifactor model inputs
mapping <- read.csv("input/mapping.csv")
mappingNames <- colnames(mapping)[2:(ncol(mapping)-6)]
normalchol <- read.csv("input/normalchol.csv")
recessionchol <- read.csv("input/recessionchol.csv")
inputmap <- read.csv("input/inputmap.csv", header=TRUE, sep=",", dec=".")
Xnames <- c("R_","pi_c_","pi_i_","pi_d_","dy_","dc_","di_","dimp_","dex_","dE_","dS_","dw_","dy_star_","pi_star_","R_star_")
Ynames <- names(inputmap)[!names(inputmap) %in% c(Xnames,"Year","Quarter","Recession")]

#get two period historical asset returns (we are using lag = 2)
histAR <- inputmap[,names(inputmap) %in% Ynames]
histAR <- histAR[(nrow(histAR)-1):nrow(histAR),]

#get two period historical macroeconomic factors (we are using lag = 2)
histMF <- inputmap[,names(inputmap) %in% Xnames]
histMF <- histMF[(nrow(histMF)-1):nrow(histMF),]

#get two period historical recession information
histRecession <- inputmap[(nrow(inputmap)-1):nrow(inputmap),names(inputmap) %in% c("Recession")]

#Recession Logistic function
recession <- function(paras, vals){
	prob <- 1/(1+exp(-sum(paras * vals)))
	if(prob > 0.5) {
		return(1)
	}else{
		return(0)
	}
}

#This is from glm_all_Recession.csv generated by fundmapping.R
glm_recession <- read.csv('input/glm_all_Recession.csv')
recession_paras <- as.vector(glm_recession$x)
# Intercept, pi_c_, dy_, dc_, di_, dE_, pi_c_1, dy_1, dc_1, di_1, dE_1, pi_c_2, dy_2, dc_2, di_2, dE_2

# esg function: create one single scenario
esg <- function(fundmap,histMF,histAR,cholNormal,cholRecession,macrofac,period, sim){
	sim <- sim %% nsims
	if (sim==0) {sim=nsims}
	macrofac <- macrofac[, colnames(macrofac) %in% c("R_", "pi_c_", "pi_i_", "pi_d_", "dy_", "dc_", "di_", "dimp_", "dex_", "dE_","dS_","dw_","dy_star_","pi_star_","R_star_")]
	sim_mf <- rbind(histMF, macrofac[(nperiod*(sim-1)+1):(nperiod*(sim-1)+period),])
	mappingX <- sim_mf
	sim_mf$recession <- 0
	sim_mf$recession[1:2] <- histRecession
	recessionX = sim_mf[, names(sim_mf) %in% c("pi_c_", "dy_", "dc_", "di_", "dE_")]
	lag <-2
	recessionNames <- c("pi_c_", "dy_", "dc_", "di_", "dE_")
	if (lag > 0) {
		for (i in c(1:lag)){
			for (varname in recessionNames){
				recessionX[(i+1):nrow(recessionX),paste0(varname,i)] <- recessionX[1:(nrow(recessionX)-i),varname]
				recessionX[1:i,paste0(varname,i)] <- NA
			}
		}
	}
	recessionX <- recessionX[(lag+1):nrow(recessionX),]
	recessionX <- cbind(Intercept = 1, recessionX)
	for (i in c(3:nrow(sim_mf))) {
		sim_mf$recession[i] <- recession(recession_paras,recessionX[i-2,])
	}
	
	sim_mf <- cbind(sim_mf,histAR)
	
	sdtnormal <- sqrt(fundmap[,names(fundmap) %in% c("tvar")])
	sdtrecession <- sqrt(fundmap[,names(fundmap) %in% c("trvar")])
	sdinormal <- sqrt(fundmap[,names(fundmap) %in% c("ivar")])
	sdirecession <- sqrt(fundmap[,names(fundmap) %in% c("irvar")])
	corrnormal <- fundmap[,names(fundmap) %in% c("tcorr")]
	corrrecession <- fundmap[,names(fundmap) %in% c("rcorr")]

	lag <-2
	if (lag > 0) {
		for (i in c(1:lag)){
			for (varname in Xnames){
				mappingX[(i+1):nrow(mappingX),paste0(varname,i)] <- mappingX[1:(nrow(mappingX)-i),varname]
				mappingX[1:i,paste0(varname,i)] <- NA
			}
		}
	}
	mappingX <- mappingX[, colnames(fundmap)[5:(ncol(fundmap)-6)]]

	for (i in c(1:period)){
		mappingX_i <- mappingX[i+2,]
		mappingX_i <- data.frame(c(1,0,0,mappingX_i))
		colnames(mappingX_i) <- mappingNames

		mappingX_i_m <- as.data.frame(lapply(mappingX_i, rep, length(sdinormal)))
		mappingX_i_m$x2 <- as.numeric(sim_mf[i,c(17:ncol(sim_mf))])
		mappingX_i_m$x1 <- as.numeric(sim_mf[i+1,c(17:ncol(sim_mf))])
		
		mappingfunc <- fundmap[,2:(ncol(fundmap)-6)]
		det_returns = rowSums(mappingfunc * mappingX_i_m)

		if (sim_mf$recession[i+2]==0){
			rnds <- t(data.matrix(normalchol)) %*% (sdinormal * rnorm(length(sdinormal)))
			rnds <- as.numeric(rnds)
		}else{
			rnds <- t(data.matrix(recessionchol)) %*% (sdirecession * rnorm(length(sdirecession)))
			rnds <- (corrrecession * det_returns + sqrt(1-corrrecession*corrrecession)*rnds) * sdirecession
			rnds <- as.numeric(rnds)/sqrt(corrrecession * corrrecession * sdtrecession * sdtrecession+(1-corrrecession*corrrecession)*sdirecession*sdirecession)
		}
		sim_mf[i+2,c(17:ncol(sim_mf))] <- det_returns + as.numeric(rnds)*1
	}
	return(sim_mf)
}

#generate asset return scenarios
set.seed(6)
nscns <- 1000


if (parallel_compute){
	# Parallel simulation using multiple cores. However, results are not reproducible
	cl <- parallel::makeCluster(4) #set number of cores to use
	doParallel::registerDoParallel(cl)
	simulations <- foreach(i = 1:nscns, .combine = 'rbind') %dopar% {
		esg(mapping,histMF,histAR,normalchol,recessionchol,results,nperiod,i)}
	parallel::stopCluster(cl)
} else {
	# This is not using parallel but results are reproducible. It is also used when generating the results.
	set.seed(6)
	simulations <- esg(mapping,histMF,histAR,normalchol,recessionchol,results,nperiod,1)
	for (i in c(1:nscns)){
		isim <- i %% nsims
		if (isim==0) {isim=nsims}
		if (i == 1){
			simulations <- esg(mapping,histMF,histAR,normalchol,recessionchol,results,nperiod,1)
		} else {
			one_scn <- esg(mapping,histMF,histAR,normalchol,recessionchol,results,nperiod,isim)
			simulations <- rbind(simulations, one_scn)
		}
		if (i %% 10 == 0){print(paste0(i," simulations are done."))}
	}
}

simulations$quarter <- rep(c((-1):nperiod),nscns)
write.csv(simulations,"esg_dsge_1k.csv",row.names=FALSE)

end_time <- Sys.time()
print(paste0("It took ", end_time - start_time, "mins to generate ", nscns, " asset return scenarios of ", nperiod, " quarters."))

#if you  do not use parallel computing, you can replicate numbers in Table 9
apply(simulations,2,mean)
apply(simulations,2,sd)

#Below are just a helper function to output percentiles by period
percs <- c(0.005,0.01,0.05, 0.1,0.25,0.5,0.75,0.9,0.95,0.99,0.995)

perc <- function(scns, ynames, percs, periods){
	modeloutput <- data.frame(y=character(),
				 period = double(),
				 min_=double(),
				 perc_005 = double(), 
				 perc_01 = double(), 
				 perc_05 = double(), 
				 perc_1 = double(), 
				 perc_25 = double(), 
				 perc_50 = double(), 
				 perc_75 = double(), 
				 perc_90 = double(), 
				 perc_95 = double(), 
				 perc_99 = double(), 
				 perc_995 = double(), 
				 max_=double(),
                 stringsAsFactors=FALSE)
		
	counter = 1

	for (yname in ynames){
		for (p in c((-1):periods)){
			idata <- scns[which(scns$quarter == p),]
			idata <- idata[,yname]
			min_ <- min(idata)
			percs_val <- quantile(idata, percs)
			max_ <- max(idata)
			modeloutput[counter,] = c(yname, p, min_, percs_val, max_)
			counter = counter + 1
		}
	
	}
	
	return(modeloutput)

}

perc(simulations,c("dy_"),percs,20)