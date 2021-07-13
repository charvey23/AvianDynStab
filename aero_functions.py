# -- This file contains all functions that are required to properly calculate the trim position --
import numpy as np
import cmath

def trim_aero(W, elbow, manus, alpha_0, aero_data):
    # use lift equation to solve for theta
    CL = get_CL(aero_data, elbow, manus, alpha_0)
    CD = get_CD(aero_data, elbow, manus, CL)
    theta_0 = np.arctan(-CD/CL)
    return theta_0


def solve_linsys(m, Iyy, rho, S_max, c_max, elbow, manus, alpha_0, U_0, theta_0, aero_data):

    CL = get_CL(aero_data, elbow, manus, alpha_0)
    CD = get_CD(aero_data, elbow, manus, CL)

    CL_alp = get_dCL_dalp(aero_data, elbow, manus, alpha_0)
    CD_alp = get_dCD_dalp(aero_data, elbow, manus, CL, CL_alp)
    Cm_alp = get_dCm_dalp(aero_data, elbow, manus, CL_alp)

    CL_q = get_dCL_dq(aero_data, elbow, manus)
    Cm_q = get_dCm_dq(aero_data, elbow, manus)

    m1_inv = 1/(2*m/(rho*U_0*S_max))
    Iyy1 = 2*Iyy/(rho*(U_0**2)*S_max*c_max)
    w1 = m*9.81/(0.5*rho*(U_0**2)*S_max)

    A = np.array([[m1_inv * (-2 * CD), m1_inv * (CL - CD_alp), 0, m1_inv * (-w1*np.cos(theta_0))],
                  [m1_inv * (-2 * CL), m1_inv * (-CD - CL_alp), 1+(-CL_q*m1_inv), m1_inv * (-w1*np.sin(theta_0))],
                  [0, Cm_alp / Iyy1, Cm_q / Iyy1, 0],
                  [0, 0, 1, 0]])

    eig_val, eig_vec = np.linalg.eig(A)
    damp = [0] * 2
    freq = [0] * 2
    mag = [0] * 16
    phase = [0] * 16

    if abs(eig_val[0].imag) > 0 and abs(eig_val[1].imag) > 0 and abs(eig_val[2].imag) > 0 and abs(eig_val[3].imag) > 0:
        damp[0] = - eig_val[0].real / np.sqrt(eig_val[0].real ** 2 + eig_val[0].imag ** 2)
        damp[1] = - eig_val[2].real / np.sqrt(eig_val[2].real ** 2 + eig_val[2].imag ** 2)

        freq[0] = np.sqrt(eig_val[0].real ** 2 + eig_val[0].imag ** 2)
        freq[1] = np.sqrt(eig_val[2].real ** 2 + eig_val[2].imag ** 2)

        count = 0
        for it1 in range(0, 4, 1):
            for it2 in range(0, 4, 1):
                phase[count] = cmath.phase(eig_vec[it2, it1])
                mag[count] = abs(eig_vec[it2, it1])
                count = count + 1

    return damp, freq, eig_val, mag, phase


def get_CL(aero_data, elbow, manus, alpha_0):
    CL = aero_data['elbow'][2]*elbow + aero_data['manus'][2]*manus + \
         aero_data['elbow2'][2]*elbow**2 + aero_data['manus2'][2]*manus**2 + \
         aero_data['manus3'][2]*manus**3 + \
         aero_data['elbowmanus'][2]*elbow*manus + aero_data['intercept'][2] + \
         aero_data['alpha'][2]*alpha_0 + aero_data['alpha2'][2]*alpha_0**2 + \
         aero_data['alpha3'][2]*alpha_0**3 + aero_data['elbowalpha'][2]*elbow*alpha_0 + \
         aero_data['manusalpha'][2]*manus*alpha_0 + aero_data['elbowmanusalpha'][2]*elbow*manus*alpha_0

    return CL


def get_dCL_dalp(aero_data, elbow, manus, alpha_0):
    CL_alp = aero_data['alpha'][2] + 2 * aero_data['alpha2'][2] * alpha_0 + \
             3 * aero_data['alpha3'][2] * alpha_0 ** 2 + aero_data['elbowalpha'][2] * elbow + \
             aero_data['manusalpha'][2] * manus + aero_data['elbowmanusalpha'][2] * elbow * manus

    return CL_alp


def get_CD(aero_data, elbow, manus, CL):
    CD = aero_data['elbow'][4]*elbow + aero_data['manus'][4]*manus + \
         aero_data['elbow2'][4]*elbow**2 + aero_data['manus2'][4]*manus**2 + \
         aero_data['manus3'][4]*manus**3 + \
         aero_data['elbowmanus'][4]*elbow*manus + aero_data['intercept'][4] + \
         aero_data['CL'][4]*CL + aero_data['CL2'][4]*CL**2 + \
         aero_data['CL3'][4]*CL**3 + aero_data['elbowCL'][4]*elbow*CL + \
         aero_data['manusCL'][4]*manus*CL + aero_data['elbowmanusCL'][4]*elbow*manus*CL

    return CD


def get_dCD_dalp(aero_data, elbow, manus, CL, CL_alp):
    cdcl = aero_data['CL'][4] + 2 * aero_data['CL2'][4] * CL + \
           3 * aero_data['CL3'][4] * CL ** 2 + aero_data['elbowCL'][4] * elbow + \
           aero_data['manusCL'][4] * manus + aero_data['elbowmanusCL'][4] * elbow * manus

    CD_alp = cdcl * CL_alp

    return CD_alp


def get_dCm_dalp(aero_data, elbow, manus, CL_alp):
    cmcl = aero_data['elbow'][1] * elbow + aero_data['manus'][1] * manus + \
           aero_data['elbow2'][1] * elbow ** 2 + aero_data['manus2'][1] * manus ** 2 + \
           aero_data['manus3'][1] * manus ** 3 + \
           aero_data['elbowmanus'][1] * elbow * manus + aero_data['intercept'][1]

    Cm_alp = cmcl * CL_alp

    return Cm_alp


def get_dCL_dq(aero_data, elbow, manus):
    CL_q = aero_data['elbow'][5]*elbow + aero_data['manus'][5]*manus + \
           aero_data['elbowmanus'][5] * elbow * manus + aero_data['intercept'][5]

    return CL_q


def get_dCm_dq(aero_data, elbow, manus):
    Cm_q = aero_data['elbow'][6]*elbow + aero_data['manus'][6]*manus + \
           aero_data['elbowmanus'][6] * elbow * manus + aero_data['intercept'][6]

    return Cm_q