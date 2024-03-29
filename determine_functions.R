library(lme4)
library(pracma)
source("support_functions.R")

## --------------- Load aerodynamic data with no tail and 0 shoulder angle -------------
# saved after running analyse_llt.R and analyze_expresults.R - no changes JRSI 2021 paper data
load("/Users/christinaharvey/Google Drive/DoctoralThesis/Chapter3_DynamicStability/aerodynamic_data.RData")
# loads:
# "dat_num" the MachUpX results for 0 shoulder sweep and dihedral 
# "dat_exp" the experimental results for 9 wings with 0 shoulder sweep and dihedral 
## --------------- Load all inertial results -------------
# function obtained https://stackoverflow.com/questions/8700619/get-specific-object-from-rdata-file
extractorRData <- function(file, object) {
  #' Function for extracting an object from a .RData file created by R's save() command
  #' Inputs: RData file, object name
  E <- new.env()
  load(file=file, envir=E)
  return(get(object, envir=E, inherits=F))
}

#saved after running process_outputdata.R Nature 2022 paper data
dat_final <- extractorRData("/Users/christinaharvey/Documents/AvInertia/AnalysisData/2021_09_03_alldata_workspace.RData","dat_final")

## --------------- Load all wing shapes -------------
dat_all <- read.csv('/Users/christinaharvey/Google Drive/DoctoralThesis/Chapter3_DynamicStability/2020_05_25_OrientedWings.csv', 
                    stringsAsFactors = FALSE,strip.white = TRUE, na.strings = c("") )
dat_all <- subset(dat_all, species == "lar_gla" & sweep == 0 & dihedral == 0)
dat_all$root_c  = sqrt((dat_all$Pt12X - dat_all$Pt11X)^2 + (dat_all$Pt12Z - dat_all$Pt11Z)^2)
dat_all$FrameID = paste("F", dat_all$frameID, sep = "")
dat_num         = merge(dat_num,dat_all[,c("species","FrameID","TestID","WingID","elbow","manus","root_c")], 
                        by = c("species","FrameID","TestID","WingID","elbow","manus"))
# determine the root chord from the previous 
dat_num$root_c_max <- 0
dat_num$root_c_max[which(dat_num$WingID == "17_0285")] = max(dat_num$root_c[which(dat_num$WingID == "17_0285")])
dat_num$root_c_max[which(dat_num$WingID == "17_0243")] = max(dat_num$root_c[which(dat_num$WingID == "17_0243")])
dat_num$root_c_max[which(dat_num$WingID == "16_0048")] = max(dat_num$root_c[which(dat_num$WingID == "16_0048")])

## --------------- Load the shoulder angle specific runs -------------
# load the MachUpX Outputs for the new runs with tails
dat_shoulder <- read.csv("/Users/christinaharvey/Google Drive/DoctoralThesis/Chapter3_DynamicStability/Outputs_MachUpX/2021_10_22_List_ConvergedWingsShoulder_Sw-10_Di10.csv",
                     header=FALSE)
tmp1 <- read.csv("/Users/christinaharvey/Google Drive/DoctoralThesis/Chapter3_DynamicStability/Outputs_MachUpX/2021_10_25_List_ConvergedWingsShoulder.csv",
                header=FALSE)
tmp2 <- read.csv("/Users/christinaharvey/Google Drive/DoctoralThesis/Chapter3_DynamicStability/Outputs_MachUpX/2021_10_30_List_ConvergedWingsShoulder.csv",
                 header=FALSE)
tmp3 <- read.csv("/Users/christinaharvey/Google Drive/DoctoralThesis/Chapter3_DynamicStability/Outputs_MachUpX/2021_11_01_List_ConvergedWingsShoulder.csv",
                 header=FALSE)
tmp4 <- read.csv("/Users/christinaharvey/Google Drive/DoctoralThesis/Chapter3_DynamicStability/Outputs_MachUpX/2021_11_03_List_ConvergedWingsShoulder.csv",
                 header=FALSE)
tmp4 <- tmp4[,1:27]
dat_shoulder <- rbind(dat_shoulder,tmp1,tmp2,tmp3,tmp4)
names(dat_shoulder) <- c("species","WingID","TestID","FrameID","sweep","dihedral","elbow","manus","alpha",
                         "U","build_err_max","date","S","ref_c","b_MX","MAC","b",
                         "tip_sweep","tip_dihedral","twist",'relax',
                         "CL","CD","Cm","FL","FD","Mm")
# Read in the standard results that are missing a sweep and dihedral column
tmp <- read.csv("/Users/christinaharvey/Google Drive/DoctoralThesis/Chapter3_DynamicStability/Outputs_MachUpX/2021_10_22_List_ConvergedWingsTail.csv",
                header=FALSE)
names(tmp) <- c("species","WingID","TestID","FrameID","elbow","manus","alpha",
                "U","build_err_max","date","S","ref_c","b_MX","MAC","b",
                "tip_sweep","tip_dihedral","twist",'relax',
                "CL","CD","Cm","FL","FD","Mm")
tmp$sweep    = 0
tmp$dihedral = 0
# re-order to match
tmp <- tmp[,c("species","WingID","TestID","FrameID","sweep","dihedral","elbow","manus","alpha",
              "U","build_err_max","date","S","ref_c","b_MX","MAC","b",
              "tip_sweep","tip_dihedral","twist",'relax',
              "CL","CD","Cm","FL","FD","Mm")]
dat_shoulder <- rbind(dat_shoulder,tmp)

dat_tail_all <- read.csv('/Users/christinaharvey/Google Drive/DoctoralThesis/Chapter3_DynamicStability/2021_10_13_dyn_subsamplewings.csv', 
                         stringsAsFactors = FALSE,strip.white = TRUE, na.strings = c("") )

# want these maximums to be taken only from the shoulder angles of 0deg as that is the only info we have for the inertial gull
# this is why it is taken from "dat_num" rather than from "dat_shoulder"
for (i in 1:nrow(dat_shoulder)){
  dat_shoulder$S_max[i]      = max(dat_num$S_max[which(dat_num$WingID == dat_shoulder$WingID[i])])
  dat_shoulder$root_c_max[i] = max(dat_num$root_c_max[which(dat_num$WingID == dat_shoulder$WingID[i])])
}

dat_shoulder$CL_adj      = dat_shoulder$FL/(0.5*1.225*10^2*dat_shoulder$S_max)
dat_shoulder$Cm_adj      = dat_shoulder$Mm/(0.5*1.225*10^2*dat_shoulder$S_max*dat_shoulder$root_c_max)
dat_shoulder$elbow_scale = dat_shoulder$elbow/1000
dat_shoulder$manus_scale = dat_shoulder$manus/1000
dat_shoulder$alpha_scale = dat_shoulder$alpha/10

## --------------- Load the q specific runs -------------

# load the q derivative specific runs - NEED TO DECIDE IF THIS NEEDS TO BE RE-RUN FOR EACH SHOULDER...
dat_q <- read.csv("/Volumes/GoogleDrive/My Drive/DoctoralThesis/Chapter3_DynamicStability/Outputs_MachUpX/2021_11_01_List_ConvergedWingsShoulder_q.csv",
                  header = FALSE)
tmp <- read.csv("/Volumes/GoogleDrive/My Drive/DoctoralThesis/Chapter3_DynamicStability/Outputs_MachUpX/2021_11_03_List_ConvergedWingsShoulder_q.csv",
                  header = FALSE)
dat_q <- rbind(tmp,dat_q)
names(dat_q) <- c("species","WingID","TestID","FrameID","sweep","dihedral","elbow","manus","alpha",
                  "U","build_err_max","date","S","ref_c","b_MX","MAC","b",
                  "tip_sweep","tip_dihedral","twist",'relax',
                  "CL","CD","Cm","FL","FD","Mm","q")

# pre-define
curr_dat_q_ind = as.data.frame(matrix(NA,nrow=1000,ncol=13))
names(curr_dat_q_ind) = c("species","WingID","TestID","FrameID","elbow","manus","sweep","dihedral","CL_q","Cm_q","CL_q_R2","Cm_q_R2","no_sample")
count_q = 1

remove(tmp,tmp1,tmp2,tmp3,tmp4) # clean up work environment

## ---------------------------------------------
## ------------- Inertia Data ------------------
## ---------------------------------------------

# subset to the same range as used in the aerodynamic data
dat_inertial = subset(dat_final,species == "lar_gla" & elbow >= 85 & manus >= 105)
remove(dat_final)

#----- Hard-coded inputs into Python --------
max(dat_inertial$full_m)
# need this to be two wings + full body area
2*max(dat_inertial$S_max) + 0.0298 
# body area was determined by 0.4/0.41*(0.0305) 
# 0.41 is the length of the estimated body in MachUpX
# 0.4 is length of inertial body 
# 0.0305 is body area taken from 3 different wings test .dist outputs from MachUpX
max(dat_inertial$c_root_max) 
# root chord approximation - calculated in the same manner as above in processdata.R 

uni_shoulder = unique(dat_shoulder[,c("sweep","dihedral")])
count = 1 # initialize

# ------ Step 0: CD data ------
# need to fit to experimental data due to the reduced - following same adjustment as the lift in analyse_exp.R
dat_exp$CD_true     <- dat_exp$D_comp/(0.5*max(dat_num$S[which(dat_num$WingID == "17_0285")])) # not included in analyse_exp.R

# NOTE: significant effect of the speed in tunnel on the drag coefficient, will limit to low only
# NOTE: interactive term elbow:manus was non-significant leave them out
# CAUTION: Assumes that drag is independent of shoulder angles (small angle approx)
# CAUTION: this model predicts the drag based on input angle of attack therefore we are not adjusting for changes in lift

mod_CD <- lm(CD_true ~ elbow + manus + alpha + I(alpha^2) + 
               elbow:I(alpha^2) + manus:I(alpha^2) + 
               elbow:alpha + manus:alpha, data = subset(dat_exp, U_des == "low"))

dat_shoulder$L_comp     = dat_shoulder$CL_adj # make sure that this is the correct lit coefficient to use to predict the drag in the next step
dat_shoulder$CD_adj_exp = predict(mod_CD,dat_shoulder)
dat_shoulder$D_adj_exp  = (0.5*1.225*10^2*dat_shoulder$S_max)*dat_shoulder$CD_adj_exp

# Calculate the estimated drag for the q derivatives as well
dat_q$CL_adj     = dat_q$FL/(0.5*1.225*10^2*max(dat_num$S[which(dat_num$WingID == "17_0285")])) # note that the wings ran for the q derivatives are only from 17_0285
dat_q$L_comp     = dat_q$CL_adj
dat_q$CD_adj_exp = predict(mod_CD,dat_q)
dat_q$D_adj_exp  = (0.5*1.225*10^2*max(dat_num$S[which(dat_num$WingID == "17_0285")]))*dat_q$CD_adj_exp

## -------------------------------------------------
## ----- Iterate through shoulder positions --------
## -------------------------------------------------

for (k in 1:nrow(uni_shoulder)){
  
  ## -------------------------------------------------
  ## ---------- Step 1: Inertial Data ----------------
  ## -------------------------------------------------
  
  # adjust all the key inertial metrics to account for the given shoulder angle
  dat_iner_curr <- adjust_inertia(uni_shoulder$sweep[k],uni_shoulder$dihedral[k],dat_inertial)
  
  # ------ CG --------
  ## need to fit model to the full_CGx_orgShoulder to allow Cm to be adjusted appropriately.
  ## fit a seperate model for each sweep and dihedral config
  mod_xcg <- lm(full_CGx_orgShoulder_adj ~ elbow*manus + I(elbow^2) + I(elbow^3) +
                  I(manus^2)+ I(manus^3), dat_iner_curr)
  
  mod_zcg <- lm(full_CGz_orgShoulder_adj ~ elbow*manus + I(elbow^2) + I(elbow^3) +
                  I(manus^2)+ I(manus^3), dat_iner_curr)
  
  ## -------------------------------------------------
  ## ---------- Step 2: Aerodynamic Data -------------
  ## -------------------------------------------------
  
  # re-allocate the current data
  dat_aero_curr = subset(dat_shoulder, 
                         sweep == uni_shoulder$sweep[k] & dihedral == uni_shoulder$dihedral[k])
  
  # ------ Cm data ------
  
  # need to adjust the moment to be calculated about the current xCG
  dat_aero_curr$xcg = predict(mod_xcg,dat_aero_curr) # the origin must be at the shoulder joint!!
  dat_aero_curr$zcg = predict(mod_zcg,dat_aero_curr) # the origin must be at the shoulder joint!!
  
  # adjust the pitching moment be about the true center of gravity
  # assumes that the MachUpX bird CG is the same distance from the shoulder as the inertial bird
  dat_aero_curr$M_CG = dat_aero_curr$Mm + ((dat_aero_curr$FL*cosd(dat_aero_curr$alpha)+dat_aero_curr$D_adj_exp*sind(dat_aero_curr$alpha))*(-dat_aero_curr$xcg) + 
                                        (dat_aero_curr$FL*sind(dat_aero_curr$alpha)-dat_aero_curr$D_adj_exp*cosd(dat_aero_curr$alpha))*(-dat_aero_curr$zcg))
  # include supplemental graph to compare the experimentally predicted drag to the MachUpX drag
  # non-dimensionalize
  dat_aero_curr$Cm_CG = dat_aero_curr$M_CG/(0.5*1.225*10^2*dat_aero_curr$S_max*dat_aero_curr$root_c_max)
  
  # ------ Step 2c: dCm/dCL data ------
  
  dat_wingspec <- unique(dat_aero_curr[c("WingID","TestID","FrameID",
                                         "elbow","manus","species","twist",
                                         "S_max","root_c_max",
                                         "elbow_scale","manus_scale")])
  no_testedconfigs = nrow(dat_wingspec)
  dat_stab_adj  <- data.frame(matrix(NA, nrow = no_testedconfigs, ncol = 9))
  names(dat_stab_adj) <- c("species","WingID","TestID","FrameID","elbow","manus",
                           "cmcl_true","cm0","R2")
  
  # need to loop through all configurations to re-calculate the static margin
  for (m in 1:no_testedconfigs){
    # subset data to be of one wing configuration at a time and subset to only fit angles under 5deg
    dat_curr <- subset(dat_aero_curr, 
                       species == dat_wingspec$species[m] & WingID == dat_wingspec$WingID[m] & 
                         TestID == dat_wingspec$TestID[m] & FrameID == dat_wingspec$FrameID[m] & alpha < 5)
    
    # save all wing specific information  
    dat_stab_adj$species[m] <- as.character(dat_wingspec$species[m])
    dat_stab_adj$WingID[m]  <- dat_wingspec$WingID[m]
    dat_stab_adj$TestID[m]  <- dat_wingspec$TestID[m]
    dat_stab_adj$FrameID[m] <- dat_wingspec$FrameID[m]
    dat_stab_adj$elbow[m]   <- dat_wingspec$elbow[m]
    dat_stab_adj$manus[m]   <- dat_wingspec$manus[m]
    
    if(nrow(dat_curr) < 4){next}
    mod.pstab = lm(Cm_CG ~ CL_adj, data = dat_curr)
    
    dat_stab_adj$cm0[m]     <- summary(mod.pstab)$coefficients[1,1]
    dat_stab_adj$cmcl_true[m]    <- summary(mod.pstab)$coefficients[2,1]
    dat_stab_adj$R2[m]      <- summary(mod.pstab)$r.squared
  }
  # remove the incomplete cases
  dat_stab_adj <- dat_stab_adj[complete.cases(dat_stab_adj[,7]),]
  dat_stab_adj$elbow_scale <- dat_stab_adj$elbow/1000
  dat_stab_adj$manus_scale <- dat_stab_adj$manus/1000
  
  mod_cmcl <- lm(cmcl_true ~ elbow_scale*manus_scale + 
                   I(elbow_scale^2) + I(elbow_scale^3) +
                   I(manus_scale^2) + I(manus_scale^3), data = dat_stab_adj)
   
  dat_aero_curr$cmcl_predict = predict(mod_cmcl,dat_aero_curr) # note this is not used in the analysis
  dat_aero_curr <- merge(dat_aero_curr,dat_stab_adj[,c("FrameID","WingID","TestID","cmcl_true")], 
                   by = c("FrameID","WingID","TestID"), all.x = TRUE)
  
  ## ----------------------------------------------------------- 
  ## ----------------- Pitch rate derivatives ------------------
  ## -----------------------------------------------------------

  curr_dat_q = subset(dat_q,
                      sweep == uni_shoulder$sweep[k] & dihedral == uni_shoulder$dihedral[k])

  # estimate the center of gravity of these configurations
  curr_dat_q$xcg = predict(mod_xcg,curr_dat_q)
  curr_dat_q$zcg = predict(mod_zcg,curr_dat_q)

  # adjust the pitching moment be about the true center of gravity
  curr_dat_q$M_CG = curr_dat_q$Mm + ((curr_dat_q$FL*cosd(curr_dat_q$alpha)+curr_dat_q$D_adj_exp*sind(curr_dat_q$alpha))*(-curr_dat_q$xcg) +
                             (curr_dat_q$FL*sind(curr_dat_q$alpha)-curr_dat_q$D_adj_exp*cosd(curr_dat_q$alpha))*(-curr_dat_q$zcg))

  # Note this pitching moment is defined relative to the root chord
  curr_dat_q$Cm_CG <- curr_dat_q$M_CG/(0.5*1.225*10^2*max(dat_num$S[which(dat_num$WingID == "17_0285")])*max(dat_num$root_c_max[which(dat_num$WingID == "17_0285")]))

  # Iterate through each Wing
  for (i in 1:length(unique(curr_dat_q$FrameID))){
    # subset the data to the current Frame
    curr_dat = subset(curr_dat_q, FrameID == unique(curr_dat_q$FrameID)[i])
    
    # skip if not enough 
    if(nrow(curr_dat) < 4){next
      count_q = count_q + 1}
    
    mod_CL_q <- lm(CL_adj ~ q + alpha, data = curr_dat)
    mod_Cm_q <- lm(Cm_CG ~ q + alpha, data = curr_dat)
    
    curr_dat_q_ind$species[count_q] <- as.character(curr_dat$species[1])
    curr_dat_q_ind$WingID[count_q]  <- curr_dat$WingID[1]
    curr_dat_q_ind$TestID[count_q]  <- curr_dat$TestID[1]
    curr_dat_q_ind$FrameID[count_q] <- curr_dat$FrameID[1]
    curr_dat_q_ind$elbow[count_q]   <- curr_dat$elbow[1]
    curr_dat_q_ind$manus[count_q]   <- curr_dat$manus[1]
    curr_dat_q_ind$sweep[count_q]   <- uni_shoulder$sweep[k]
    curr_dat_q_ind$dihedral[count_q]<- uni_shoulder$dihedral[k]
    
    curr_dat_q_ind$CL_q[count_q]      <- coefficients(mod_CL_q)["q"]
    curr_dat_q_ind$Cm_q[count_q]      <- coefficients(mod_Cm_q)["q"]
    curr_dat_q_ind$CL_q_R2[count_q]   <- summary(mod_CL_q)$r.squared
    curr_dat_q_ind$Cm_q_R2[count_q]   <- summary(mod_Cm_q)$r.squared
    curr_dat_q_ind$no_sample[count_q] <- nrow(curr_dat)
    count_q = count_q + 1
  }
  
  ## ----------------------------------------------------------- 
  ## -------------------- Save output data ---------------------
  ## -----------------------------------------------------------
  dat_iner_curr$sweep    = uni_shoulder$sweep[k]
  dat_iner_curr$dihedral = uni_shoulder$dihedral[k]
  
  if (k == 1){
    dat_aero_all = dat_aero_curr
    dat_iner_all = dat_iner_curr
  }else{
    dat_aero_all = rbind(dat_aero_all, dat_aero_curr)
    dat_iner_all = rbind(dat_iner_all, dat_iner_curr)
  }
}


# ------ SAVE OUTPUT COEFFICIENTS ------

coef_all = as.data.frame(matrix(0,nrow = 6, ncol = 44))
colnames(coef_all) <- c("y.model",
                        "intercept","elbow","manus","sweep","dihedral",
                        "alpha","alpha2","alpha3","alpha4",
                        "elbow2","elbow3","manus2","manus3",
                        "sweep2","dihedral2",
                        "elbowmanus","elbowsweep","manussweep",
                        "elbowdihedral","manusdihedral",
                        "sweepdihedral","elbowmanussweep","elbowmanusdihedral",
                        "elbowsweepdihedral","manussweepdihedral",
                        "elbowmanussweepdihedral",
                        "elbowalpha","manusalpha",
                        "sweepalpha","dihedralalpha", "elbowmanusalpha",
                        "CL","CL_q","elbowmanusCL","elbowsweepCL",
                        "manussweepCL","elbowmanussweepCL",
                        "elbowCL","manusCL","sweepCL","dihedralCL",
                        "elbowalpha2","manusalpha2")

# ------ Step 1a: Iyy data ------
#  !! CAUTION: Maximum elbow = 152 and Max wrist = 167 in inertial data 
# Must INCLUDE NOTE IN PAPER THAT I EFFECTIVELY AM EXTRAPOLATING THE INERTIAL RESULS INTO HIGHER ELBOW AND WRIST ANGLES
mod_inertia <- lm(full_Iyy_adj ~ elbow*manus*sweep*dihedral + 
                    I(elbow^2) + I(manus^2) + I(sweep^2) + I(dihedral^2), dat_iner_all)

coef_all$y.model[1]                 = "Iyy"
coef_all$intercept[1]               = coef(mod_inertia)["(Intercept)"]
coef_all$elbow[1]                   = coef(mod_inertia)["elbow"]
coef_all$manus[1]                   = coef(mod_inertia)["manus"]
coef_all$sweep[1]                   = coef(mod_inertia)["sweep"]
coef_all$dihedral[1]                = coef(mod_inertia)["dihedral"]
coef_all$elbow2[1]                  = coef(mod_inertia)["I(elbow^2)"]
coef_all$manus2[1]                  = coef(mod_inertia)["I(manus^2)"]
coef_all$sweep2[1]                  = coef(mod_inertia)["I(sweep^2)"]
coef_all$dihedral2[1]               = coef(mod_inertia)["I(dihedral^2)"]
coef_all$elbowmanus[1]              = coef(mod_inertia)["elbow:manus"]
coef_all$elbowsweep[1]              = coef(mod_inertia)["elbow:sweep"]
coef_all$manussweep[1]              = coef(mod_inertia)["manus:sweep"]
coef_all$elbowdihedral[1]           = coef(mod_inertia)["elbow:dihedral"]
coef_all$manusdihedral[1]           = coef(mod_inertia)["manus:dihedral"]
coef_all$sweepdihedral[1]           = coef(mod_inertia)["sweep:dihedral"]
coef_all$elbowmanussweep[1]         = coef(mod_inertia)["elbow:manus:sweep"]
coef_all$elbowmanusdihedral[1]      = coef(mod_inertia)["elbow:manus:dihedral"]
coef_all$elbowsweepdihedral[1]      = coef(mod_inertia)["elbow:sweep:dihedral"]
coef_all$manussweepdihedral[1]      = coef(mod_inertia)["manus:sweep:dihedral"]
coef_all$elbowmanussweepdihedral[1] = coef(mod_inertia)["elbow:manus:sweep:dihedral"]

# ------ Step 2a: CL data ------
# scaling was elbow/1000 manus/1000 alpha/10
# If I want to input the true values into this same model I instead
# need to divide each coefficient by however many inputs are being changed
mod_CL <- lm(CL_adj ~ elbow_scale*manus_scale*alpha_scale + 
               I(alpha_scale^2) + I(alpha_scale^3) +
               I(elbow_scale^2) + I(manus_scale^2) + I(manus_scale^3) +
               sweep + dihedral + 
               sweep:alpha_scale + dihedral:alpha_scale, data = subset(dat_aero_all,alpha < 5))

coef_all$y.model[2]            = "CL"
coef_all$intercept[2]          = coef(mod_CL)["(Intercept)"]
coef_all$elbow[2]              = coef(mod_CL)["elbow_scale"]/1000
coef_all$manus[2]              = coef(mod_CL)["manus_scale"]/1000
coef_all$alpha[2]              = coef(mod_CL)["alpha_scale"]/10
coef_all$alpha2[2]             = coef(mod_CL)["I(alpha_scale^2)"]/(10^2)
coef_all$alpha3[2]             = coef(mod_CL)["I(alpha_scale^3)"]/(10^3)
coef_all$elbow2[2]             = coef(mod_CL)["I(elbow_scale^2)"]/(1000^2)
coef_all$manus2[2]             = coef(mod_CL)["I(manus_scale^2)"]/(1000^2)
coef_all$manus3[2]             = coef(mod_CL)["I(manus_scale^3)"]/(1000^3)
coef_all$sweep[2]              = coef(mod_CL)["sweep"]
coef_all$dihedral[2]           = coef(mod_CL)["dihedral"]
coef_all$elbowmanus[2]         = coef(mod_CL)["elbow_scale:manus_scale"]/(1000^2)
coef_all$elbowalpha[2]         = coef(mod_CL)["elbow_scale:alpha_scale"]/(1000*10)
coef_all$manusalpha[2]         = coef(mod_CL)["manus_scale:alpha_scale"]/(1000*10)
coef_all$sweepalpha[2]         = coef(mod_CL)["alpha_scale:sweep"]/(10)
coef_all$dihedralalpha[2]      = coef(mod_CL)["alpha_scale:dihedral"]/(10)
coef_all$elbowmanusalpha[2]    = coef(mod_CL)["elbow_scale:manus_scale:alpha_scale"]/(1000^2*10)
# ------ Step 2b: CD data ------

coef_all$y.model[3]      = "CD"
coef_all$intercept[3]    = coef(mod_CD)["(Intercept)"]
coef_all$elbow[3]        = coef(mod_CD)["elbow"]
coef_all$manus[3]        = coef(mod_CD)["manus"]
coef_all$alpha[3]        = coef(mod_CD)["alpha"]
coef_all$alpha2[3]       = coef(mod_CD)["I(alpha^2)"]
coef_all$elbowalpha2[3]  = coef(mod_CD)["elbow:I(alpha^2)"]
coef_all$manusalpha2[3]  = coef(mod_CD)["manus:I(alpha^2)"]
coef_all$elbowalpha[3]   = coef(mod_CD)["elbow:alpha"]
coef_all$manusalpha[3]   = coef(mod_CD)["manus:alpha"]

# ------ Step 2c: Cm data ------
mod_Cm <- lm(Cm_CG ~ elbow_scale*manus_scale*sweep*CL_adj + 
               I(elbow_scale^2) + I(elbow_scale^3) + 
               I(manus_scale^2) + dihedral + dihedral:CL_adj, data = subset(dat_aero_all,alpha < 5))

coef_all$y.model[4]            = "Cm"
coef_all$intercept[4]          = coef(mod_Cm)["(Intercept)"]
coef_all$elbow[4]              = coef(mod_Cm)["elbow_scale"]/1000
coef_all$manus[4]              = coef(mod_Cm)["manus_scale"]/1000
coef_all$CL[4]                 = coef(mod_Cm)["CL_adj"]
coef_all$elbow2[4]             = coef(mod_Cm)["I(elbow_scale^2)"]/(1000^2)
coef_all$elbow3[4]             = coef(mod_Cm)["I(elbow_scale^3)"]/(1000^3)
coef_all$manus2[4]             = coef(mod_Cm)["I(manus_scale^2)"]/(1000^2)
coef_all$sweep[4]              = coef(mod_Cm)["sweep"]
coef_all$dihedral[4]           = coef(mod_Cm)["dihedral"]
coef_all$elbowmanus[4]         = coef(mod_Cm)["elbow_scale:manus_scale"]/(1000^2)
coef_all$elbowsweep[4]         = coef(mod_Cm)["elbow_scale:sweep"]/(1000)
coef_all$manussweep[4]         = coef(mod_Cm)["manus_scale:sweep"]/(1000)
coef_all$elbowCL[4]            = coef(mod_Cm)["elbow_scale:CL_adj"]/(1000)
coef_all$manusCL[4]            = coef(mod_Cm)["manus_scale:CL_adj"]/(1000)
coef_all$sweepCL[4]            = coef(mod_Cm)["sweep:CL_adj"]
coef_all$dihedralCL[4]         = coef(mod_Cm)["CL_adj:dihedral"]
coef_all$elbowmanussweep[4]    = coef(mod_Cm)["elbow_scale:manus_scale:sweep"]/(1000^2)
coef_all$elbowmanusCL[4]       = coef(mod_Cm)["elbow_scale:manus_scale:CL_adj"]/(1000^2)
coef_all$elbowsweepCL[4]       = coef(mod_Cm)["elbow_scale:sweep:CL_adj"]/(1000)
coef_all$manussweepCL[4]       = coef(mod_Cm)["manus_scale:sweep:CL_adj"]/(1000)
coef_all$elbowmanussweepCL[4]  = coef(mod_Cm)["elbow_scale:manus_scale:sweep:CL_adj"]/(1000^2)

# remove the incomplete cases
curr_dat_q_ind <- curr_dat_q_ind[complete.cases(curr_dat_q_ind[,7]),]

# ------ Step 2d: dCL/dq data ------
# This method assumes that there is no effect of angle of attack on dCL/dq
mod_CL_q_ind <- lm(CL_q ~ elbow*manus*sweep + dihedral, data = curr_dat_q_ind)

coef_all$y.model[5]         = "dCLdq"
coef_all$intercept[5]       = coef(mod_CL_q_ind)["(Intercept)"]
coef_all$elbow[5]           = coef(mod_CL_q_ind)["elbow"]
coef_all$manus[5]           = coef(mod_CL_q_ind)["manus"]
coef_all$sweep[5]           = coef(mod_CL_q_ind)["sweep"]
coef_all$dihedral[5]        = coef(mod_CL_q_ind)["dihedral"]
coef_all$elbowmanus[5]      = coef(mod_CL_q_ind)["elbow:manus"]
coef_all$elbowsweep[5]      = coef(mod_CL_q_ind)["elbow:sweep"]
coef_all$manussweep[5]      = coef(mod_CL_q_ind)["manus:sweep"]
coef_all$elbowmanussweep[5] = coef(mod_CL_q_ind)["elbow:manus:sweep"]

# ------ Step 2e: dCm/dq data ------
# This method assumes that there is no effect of angle of attack on dCm/dq
mod_Cm_q_ind <- lm(Cm_q ~ elbow + manus + sweep + dihedral + CL_q, data = curr_dat_q_ind)

coef_all$y.model[6]    = "dCmdq"
coef_all$intercept[6]  = coef(mod_Cm_q_ind)["(Intercept)"]
coef_all$elbow[6]      = coef(mod_Cm_q_ind)["elbow"]
coef_all$manus[6]      = coef(mod_Cm_q_ind)["manus"]
coef_all$sweep[6]      = coef(mod_Cm_q_ind)["sweep"]
coef_all$dihedral[6]   = coef(mod_Cm_q_ind)["dihedral"]
coef_all$CL_q[6]       = coef(mod_Cm_q_ind)["CL_q"]

## ----------------------------------------------------------- 
## -------------------- Save output data ---------------------
## -----------------------------------------------------------
filename = paste(format(Sys.Date(), "%Y_%m_%d"),"_coefficients_all.csv",sep="")
write.csv(coef_all,paste('/Users/christinaharvey/Google Drive/DoctoralThesis/Chapter3_DynamicStability/coefficients/',filename,sep=""))

mod_xcg_full <- lm(xcg ~ elbow*manus*sweep*dihedral, dat_aero_all)
mod_zcg_full <- lm(zcg ~ elbow*manus*sweep*dihedral, dat_aero_all)
