# -- This file contains all functions that are required to properly calculate the trim position --
import numpy as np
import scipy.optimize as opt


def trim_aero(W, rho, S, elbow, manus, sw, di, aero_data):

    # Step 1: Check if the Cm when Lift = 0 is positive
    Cm0 = get_Cm(aero_data, elbow, manus, sw, di, 0)
    # Step 2: Calculate the slope
    cm_cl = get_dCm_dCL(aero_data, elbow, manus, sw, di)
    # Step 3: Calculate the lift when Cm = 0
    CL = -Cm0/cm_cl

    # EARLY EXIT: it won't be possible to trim if the Cm0 is less than 0 while dCm/dCL is negative
    if Cm0 < 0 and cm_cl < 0:
        return "NA", "NA", "NA"

    # EARLY EXIT: it won't be possible to trim if the Cm0 is greater than 0 while dCm/dCL is positive
    if Cm0 > 0 and cm_cl > 0:
        return "NA", "NA", "NA"

    # Step 4: Determine the angle of attack associated with this lift
    alpha_guess = np.array([0])
    alpha_sol = opt.minimize(trim_alpha, alpha_guess,
                             args=(elbow, manus, sw, di, aero_data, CL))
    alpha_0 = alpha_sol.x[0]

    # Step 5: Estimate the drag at this lift
    CL = get_CL(aero_data, elbow, manus, sw, di, alpha_0)
    CD = get_CD(aero_data, elbow, manus, alpha_0)

    # Step 6: Solve the force equations for speed (Ve) and flight path angle in radians (gamma) at this angle of attack
    # CAUTION: Flight path angle (gamma_rad) is the angle between the horizon and the velocity vector
    # i.e. gamma_rad = theta_rad - alpha_rad
    force_guess = np.array([10, 0*np.pi/180])
    force_sol = opt.minimize(trim_force, force_guess,
                           args=(W, rho, S, CL, CD))

    # EARLY EXIT: make sure this result actually solved for an equilibrium
    if abs(force_sol.fun) > 10e-6:
        force_guess = np.array([15, -5 * np.pi / 180])
        force_sol = opt.minimize(trim_force, force_guess,
                                 args=(W, rho, S, CL, CD))
        if abs(force_sol.fun) > 10e-6:
            force_guess = np.array([20, -10 * np.pi / 180])
            force_sol = opt.minimize(trim_force, force_guess,
                                     args=(W, rho, S, CL, CD))
            if abs(force_sol.fun) > 10e-6:
                force_guess = np.array([25, -5 * np.pi / 180])
                force_sol = opt.minimize(trim_force, force_guess,
                                         args=(W, rho, S, CL, CD))
                if abs(force_sol.fun) > 10e-6:
                    force_guess = np.array([25, -30 * np.pi / 180])
                    force_sol = opt.minimize(trim_force, force_guess,
                                             args=(W, rho, S, CL, CD))
                    if abs(force_sol.fun) > 10e-6:
                        return "NA", "NA", "NA"

    # Step 7: Save outputs
    # Note: These constraints are used in the solving which is why the numbers are saved like this
    V_e = abs(force_sol.x[0])
    gamma_rad = -abs(force_sol.x[1])
    if gamma_rad < -0.5*np.pi:
        gamma_rad = -0.5*np.pi

    return gamma_rad, V_e, alpha_0


def get_CL(aero_data, elbow, manus, sweep, dihedral, alpha_0):
    # incoming alpha should be in degrees
    CL = aero_data['intercept'][1] + \
         aero_data['elbow'][1] * elbow + \
         aero_data['manus'][1] * manus + \
         aero_data['sweep'][1] * sweep + \
         aero_data['dihedral'][1] * dihedral + \
         aero_data['alpha'][1] * alpha_0 + \
         aero_data['alpha2'][1] * (alpha_0 ** 2) + \
         aero_data['alpha3'][1] * (alpha_0 ** 3) + \
         aero_data['elbow2'][1] * (elbow ** 2) +\
         aero_data['manus2'][1] * (manus ** 2) + \
         aero_data['manus3'][1] * (manus ** 3) + \
         aero_data['elbowmanus'][1] * elbow * manus + \
         aero_data['elbowalpha'][1] * elbow * alpha_0 + \
         aero_data['manusalpha'][1] * manus * alpha_0 + \
         aero_data['sweepalpha'][1] * sweep * alpha_0 + \
         aero_data['dihedralalpha'][1] * dihedral * alpha_0 + \
         aero_data['elbowmanusalpha'][1] * elbow * manus * alpha_0

    return CL


def get_dCL_dalp(aero_data, elbow, manus, sweep, dihedral, alpha_0):
    # incoming alpha should be in degrees
    CL_alp = aero_data['alpha'][1] + \
             2 * aero_data['alpha2'][1] * alpha_0 + \
             3 * aero_data['alpha3'][1] * (alpha_0 ** 2) + \
             aero_data['elbowalpha'][1] * elbow + \
             aero_data['manusalpha'][1] * manus + \
             aero_data['sweepalpha'][1] * sweep + \
             aero_data['dihedralalpha'][1] * dihedral + \
             aero_data['elbowmanusalpha'][1] * elbow * manus

    # CAUTION THE INPUT ANGLE OF ATTACK IS IN DEGREES
    CL_alp = CL_alp/(np.pi/180)
    # output will be in radians
    return CL_alp


def get_CD(aero_data, elbow, manus, alpha_0):
    CD = aero_data['intercept'][2] + \
         aero_data['elbow'][2] * elbow + \
         aero_data['manus'][2] * manus + \
         aero_data['alpha'][2] * alpha_0 + \
         aero_data['alpha2'][2] * (alpha_0 ** 2) + \
         aero_data['elbowalpha'][2] * elbow * \
         alpha_0 + aero_data['manusalpha'][2] * manus * alpha_0 + \
         aero_data['elbowalpha2'][2] * elbow * (alpha_0 ** 2) + \
         aero_data['manusalpha2'][2] * manus * (alpha_0 ** 2)

    return CD


def get_dCD_dalp(aero_data, elbow, manus, alpha_0):
    CD_alp = aero_data['alpha'][2] + \
             2 * aero_data['alpha2'][2] * alpha_0 + \
             aero_data['elbowalpha'][2] * elbow + \
             aero_data['manusalpha'][2] * manus + \
             2 * aero_data['elbowalpha2'][2] * elbow * alpha_0 + \
             2 * aero_data['manusalpha2'][2] * manus * alpha_0

    # CAUTION THE INPUT ANGLE OF ATTACK IS IN DEGREES
    CD_alp = CD_alp/(np.pi/180)
    # output will be in radians
    return CD_alp


def get_Cm(aero_data, elbow, manus, sweep, dihedral,  CL):
    Cm = aero_data['intercept'][3] + \
         aero_data['elbow'][3] * elbow + \
         aero_data['manus'][3] * manus + \
         aero_data['sweep'][3] * sweep + \
         aero_data['dihedral'][3] * dihedral + \
         aero_data['CL'][3]*CL + \
         aero_data['elbow2'][3] * (elbow ** 2) + \
         aero_data['elbow3'][3] * (elbow ** 3) + \
         aero_data['manus2'][3] * (manus ** 2) + \
         aero_data['elbowmanus'][3] * elbow * manus + \
         aero_data['elbowsweep'][3] * elbow * sweep + \
         aero_data['manussweep'][3] * manus * sweep + \
         aero_data['elbowCL'][3] * elbow * CL + \
         aero_data['manusCL'][3] * manus * CL + \
         aero_data['sweepCL'][3] * sweep * CL + \
         aero_data['dihedralCL'][3] * dihedral * CL + \
         aero_data['elbowmanussweep'][3] * elbow * manus * sweep + \
         aero_data['elbowmanusCL'][3] * elbow * manus * CL + \
         aero_data['elbowsweepCL'][3] * elbow * sweep * CL + \
         aero_data['manussweepCL'][3] * manus * sweep * CL + \
         aero_data['elbowmanussweepCL'][3] * elbow * manus * sweep * CL

    return Cm


def get_dCm_dCL(aero_data, elbow, manus, sweep, dihedral):
    cmcl = aero_data['CL'][3] + \
           aero_data['elbowCL'][3] * elbow + \
           aero_data['manusCL'][3] * manus + \
           aero_data['sweepCL'][3] * sweep + \
           aero_data['dihedralCL'][3] * dihedral + \
           aero_data['elbowmanusCL'][3] * elbow * manus + \
           aero_data['elbowsweepCL'][3] * elbow * sweep + \
           aero_data['manussweepCL'][3] * manus * sweep + \
           aero_data['elbowmanussweepCL'][3] * elbow * manus * sweep

    return cmcl


def get_dCL_dq(aero_data, elbow, manus, sweep, dihedral):
    CL_q = aero_data['intercept'][4] + \
           aero_data['elbow'][4]*elbow + \
           aero_data['manus'][4]*manus + \
           aero_data['sweep'][4]*sweep + \
           aero_data['dihedral'][4]*dihedral + \
           aero_data['elbowmanus'][4] * elbow * manus + \
           aero_data['elbowsweep'][4] * elbow * sweep + \
           aero_data['manussweep'][4] * manus * sweep + \
           aero_data['elbowmanussweep'][4] * elbow * manus * sweep
        # output will be in radians because incoming q is in radians
    return CL_q


def get_dCm_dq(aero_data, elbow, manus, sweep, dihedral, CL_q):
    Cm_q = aero_data['intercept'][5] + \
           aero_data['elbow'][5]*elbow + \
           aero_data['manus'][5]*manus + \
           aero_data['sweep'][5]*sweep + \
           aero_data['dihedral'][5]*dihedral + \
           aero_data['CL_q'][5] * CL_q

    # output will be in radians because incoming q is in radians
    return Cm_q


def min_geo_angle(x, Cm, CL, CD, alpha, c_root):

    z = (c_root/(CL*np.sin(alpha)-CD*np.cos(alpha)))*(Cm - ((CL*np.cos(alpha)+CD*np.sin(alpha))*(x/c_root)))
    out = x**2 + z**2

    return out


def trim_force(x, W, rho, S, CL, CD):
    V = abs(x[0])
    gamma_rad = -abs(x[1])

    if gamma_rad < -0.5*np.pi:
        gamma_rad = -0.5*np.pi

    F = np.empty(2)
    # x direction forces
    F[0] = - (0.5 * rho * V ** 2 * S * CD) - W * np.sin(gamma_rad)
    # z direction forces
    F[1] = - (0.5 * rho * V ** 2 * S * CL) + W * np.cos(gamma_rad)

    return F[0]**2+F[1]**2


def trim_alpha(x, elbow, manus, sweep, dihedral, aero_data, CL):
    alpha_0 = x
    CL_calc = get_CL(aero_data, elbow, manus, sweep, dihedral, alpha_0)

    return (CL_calc-CL) ** 2
