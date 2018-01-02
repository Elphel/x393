#!/usr/bin/env python
# encoding: utf-8
from __future__ import division
from __future__ import print_function

'''
# Copyright (C) 2016, Elphel.inc.
# Class to calculate DCT-IV and DST-IV
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http:#www.gnu.org/licenses/>.

@author:     Andrey Filippov
@copyright:  2017 Elphel, Inc.
@license:    GPLv3.0+
@contact:    andrey@elphel.coml
@deffield    updated: Updated
'''
__author__ = "Andrey Filippov"
__copyright__ = "Copyright 2015, Elphel, Inc."
__license__ = "GPL"
__version__ = "3.0+"
__maintainer__ = "Andrey Filippov"
__email__ = "andrey@elphel.com"
__status__ = "Development"
import math
#import sys
#import pickle
COSPI_1_8_SQRT2 = math.cos(math.pi/8)*math.sqrt(2.0);
COSPI_3_8_SQRT2 = math.cos(3*math.pi/8)*math.sqrt(2.0);
SQRT2 = math.sqrt(2.0);
SQRT1_2 = 1/SQRT2

class DttRad2(object):
    CN1 = {}
    SN1 = {}
    def __init__(self):
        pass

    def ilog2(self, n):
        i = 0
        while n > 1:
            i+=1
            n >>=1
        return i    

    def setup_arrays(self, n):
        
        if n in self.CN1.keys():
            return
        n1 = n >> 1
        if n1 > 2:
            self.setup_arrays(n1)

        self.CN1[n] = [0.0]*n1
        self.SN1[n] = [0.0]*n1
        pi_4n=math.pi/(8*n1) # // n1 = n/2
        for k in range(n1):
            self.CN1[n][k] = math.cos((2*k+1)*pi_4n);
            self.SN1[n][k] = math.sin((2*k+1)*pi_4n);

        print("CN1=",self.CN1)
        print("SN1=",self.SN1)

    def _dctii_recurs(self,x):
        n = len(x)
        if (n ==2 ):
            return [x[0]+x[1],x[0]-x[1]]
        n1 = n >> 1;
        u0 = [0.0]*n1
        u1 = [0.0]*n1
        # // u = sqrt(2)*Tn(0) * x
        for j in range(n1):
            u0[j]=            (x[j] +    x[n-j-1])
            u1[j]=            (x[j] -    x[n-j-1])
        v0 = self._dctii_recurs(u0);
        v1 = self._dctiv_recurs(u1);
        y = [0.0]*n
        for j in range(n1):
            y[2*j] =     v0[j]
            y[2*j+1] =   v1[j]
        return y


    def _dctiv_recurs(self, x):
        n = len(x)
        if (n ==2 ):
            return [COSPI_1_8_SQRT2*x[0] + COSPI_3_8_SQRT2*x[1], COSPI_3_8_SQRT2*x[0] - COSPI_1_8_SQRT2*x[1]]
        n1 = n >> 1
        u0 = [0.0]*n1
        u1 = [0.0]*n1
        #// u = sqrt(2)*Tn(1) * x
        for j in range(n1):
#            print("n=",n," n1=",n1," j=",j)            
            u0[j]=                             ( self.CN1[n][j] *      x[j] +      self.SN1[n][j] *         x[n -  j - 1]);
            u1[j]=            ( 1 - 2*(j & 1))*(-self.SN1[n][n1-j-1] * x[n1-j-1] + self.CN1[n][n1 - j -1] * x[n1 + j    ]);
        v0 = self._dctii_recurs(u0)
        v1 = self._dctii_recurs(u1) # //both cos-II


        w0 = [0.0]*n1
        w1 = [0.0]*n1

        w0[0] =     SQRT2 * v0[0];
        w1[n1-1] =     SQRT2 * v1[0];
        for j in range (n1):
            sgn = (1 - 2* (j & 1));
            if (j > 0):
                w0[j] = v0[j]   - sgn * v1[n1 - j];
            if (j < (n1-1)):
                w1[j] = v0[j+1] - sgn * v1[n1 - j -1];

        y = [0.0]*n
        for j in range(n1):
            y[2*j] =     w0[j];
            y[2*j+1] =   w1[j];
        return y


    def dct_ii(self, x):
        n = len(x)
        self.setup_arrays(n)        
        y=  self._dctii_recurs(x);
        scale = 1.0/math.sqrt(n)
        for i in range (n):
            y[i] *= scale
        return y

    def dct_iv(self, x):
        n = len(x)
        self.setup_arrays(n)        
        y=  self._dctiv_recurs(x);
        scale = 1.0/math.sqrt(n)
        for i in range (n):
            y[i] *= scale
        return y

    def dst_iv(self, x):
        n = len(x)
        self.setup_arrays(n)        
        xr= x[:] # clone
        xr.reverse()
        y=  self._dctiv_recurs(xr);
        scale = 1.0/math.sqrt(n);
        for i in range (n):
            y[i] *= scale;
            scale = -scale;
        return y;
    def mclt_window_sin(self,n, offset=0):
        """
        Generate offset MCLT sine window
        @param n - DTT length (half MCLT)
        @param offset - window offset
        @return window array 2*n elements long. All positive in the range 0.0..1.0
        """
        n2 = 2 * n
        w = [0.0]*n2
        for i in range(n2):
            w[i] = math.sin(math.pi*(i+0.5-offset)/n2)
        return w
    def mclt_window_sin_mod(self,n, offset=0.0, flat = 0.0):
        """
        Generate offset MCLT sine window
        @param n - DTT length (half MCLT)
        @param offset - window offset
        @param flat - extend zeros on the ends (by this), flat 1.0 in the center (by twice that).
               Valid Princen-Bradley condition
        @return window array 2*n elements long. All positive in the range 0.0..1.0
        """
        n2 = 2 * n
        w = [0.0]*n2
#        k = 1.0*(n- 2 * flat)/n
        k = 1.0*n/(n- 2 * flat)
        for i in range(n2):
            a = (i+0.5-offset)/n2 # 1.0 is pi
            if a > 0.5:
                a = 1.0 - a
            a = 0.25 + k*(a - 0.25)
            if a < 0:
                a = 0
            elif a > 0.5:
                a = 0.5
            w[i] = math.sin(math.pi*a)
        return w
    def fold_dtt(self,x,sine_mode=False):
        """
        Fold MDCT/MDST sequence twice making an input for DCT-IV /DST-IV conversion (half length
        @param x input data sequence
        @param sine_mode: False - for DCT-IV, True - for DST-IV 
        @return array of DCT-IV/DST-IV folded data, 1/2 length of the input sequence
        """
        n2 = len(x)
        n = n2 >> 1
        n05 = n >> 1
        n15 = n + n05
        y = [0.0]* n
        sgn = (1.0,-1.0)[sine_mode]
        for i in range(n05):
            y[      i] = -sgn * x[n15 - 1 - i]       -x[n15  + i] # -/+ c' - d 
            y[n05 + i] =        x[i]           -sgn * x[n -1 - i] # a    -/+ b' 
        return y
    
    def mclt_norot(self, x, offset=0.0, flat = 0.0):
        """
        Perform direct MCLT transform, using offset (and modified) sine window
        @param x input data sequence (will not be modified)
        @param offset - window offset
        @param flat - extend window zeros on the ends (by this), flat 1.0 in the center (by twice that).
               Valid Princen-Bradley condition
        @return array of [[DCT-IV],[DST-IV]], each 1/2 length of the input sequence
        """
        n2 = len(x)
        n = n2 >> 1
        w = self.mclt_window_sin_mod(n, offset, flat)
        xc = x[:]
        for i in range(n2):
            xc[i] *= w[i]
        return (self.dct_iv(self.fold_dtt(xc,False)), # DCT-IV
                self.dst_iv(self.fold_dtt(xc,True)))  # DST-IV


         
        
    def unfold_dtt(self,x,sine_mode=False):
        """
        Unfold MDCT/MDST sequence twice after IDTT-IV before multiplying by a window
        [F,S]: after DCT-IV: [S, -S', -F', -F], after DST-IV: [S,  S', F', -F]
        @param x input data sequence from IDCT-IV/IDST-IV
        @param sine_mode: False - for IDCT-IV, True - for IDST-IV 
        @return array of unfolded data, twice length of the input sequence
        """
        n = len(x)
        n2 = n << 1
        n05 = n >> 1
        n15 = n + n05
        y = [0.0]* n2
        sgn = (1.0,-1.0)[sine_mode]
        for i in range(n05):
            y[      i] =        x[n05    + i] # S
            y[n05 + i] = -sgn*  x[n   -1 - i] # -/+S'
            y[n   + i] = -sgn*  x[n05 -1 - i] # -/+F'
            y[n15 + i] =       -x[         i] #   -F
        return y
    
    def imclt(self, cs, flat = 0.0):
        """
        Perform inverse MCLT transform, using modified sine window
        @param cs - frequency domain data [[IDCT-IV],[IDST-IV]]
        @param flat - extend window zeros on the ends (by this), flat 1.0 in the center (by twice that).
               Valid Princen-Bradley condition
        @return array of pixel domain lapped data, twice dct size
        """
        n = len(cs[0])
        n2 = n << 1
        xc = self.unfold_dtt(self.dct_iv(cs[0]), False)
        xs = self.unfold_dtt(self.dst_iv(cs[1]), True)
        w = self.mclt_window_sin_mod(n, 0, flat) # may use cached data
        for i in range(n2):
            xc[i] = 0.5* w[i]*(xc[i]+xs[i])
        return xc
    
    def clt_rot(self, cs, shft):
        """
        Perform frequency domain phase rotation equivalent to pixel shift
        @param cs - frequency domain data [[IDCT-IV],[IDST-IV]]
        @param shft - shift in pixels
        @return same format as input - rotated(shifted) frequency domain data
        """
        n = len(cs[0])
        rcs = [[0.0]*n, [0.0]*n]
        a=math.pi*shft/n
        for i in range(n):
            cosi = math.cos(a*(i+0.5))
            sini = math.sin(a*(i+0.5))
            rcs[0][i] = cs[0][i] * cosi - cs[1][i] * sini
            rcs[1][i] = cs[1][i] * cosi + cs[0][i] * sini
        return rcs


##################
    def test_mclt(self, plt, dbg_x, cmode, x, offset=0.0, flat = 0.0):
        """
        Perform direct MCLT transform, using offset (and modified) sine window
        @param x input data sequence (will not be modified)
        @param offset - window offset
        @param flat - extend window zeros on the ends (by this), flat 1.0 in the center (by twice that).
               Valid Princen-Bradley condition
        @return array of [[DCT-IV],[DST-IV]], each 1/2 length of the input sequence
        """
        n2 = len(x)
        n = n2 >> 1
        w = self.mclt_window_sin_mod(n, offset, flat)
        print ("w=",w)
        xc = x[:]
        for i in range(n2):
            xc[i] *= w[i]
        plt.plot(dbg_x, xc, cmode)
        print ("test_mclt xc=",xc)
        print ("test_mclt cos=",self.fold_dtt(xc,False))
        print ("test_mclt sin=",self.fold_dtt(xc,True))
        return (self.fold_dtt(xc,False), # DCT-IV
                self.fold_dtt(xc,True))  # DST-IV




    def test_mclt0(self, plt, dbg_x, cmode, x, offset=0.0, flat = 0.0):
        """
        Perform direct MCLT transform, using offset (and modified) sine window
        @param x input data sequence (will not be modified)
        @param offset - window offset
        @param flat - extend window zeros on the ends (by this), flat 1.0 in the center (by twice that).
               Valid Princen-Bradley condition
        @return array of [[DCT-IV],[DST-IV]], each 1/2 length of the input sequence
        """
        n2 = len(x)
        n = n2 >> 1
        w = self.mclt_window_sin_mod(n, offset, flat)
        print ("w=",w)
        xc = x[:]
        for i in range(n2):
            xc[i] *= w[i]
        plt.plot(dbg_x, xc, cmode)
        return xc            
        return (self.fold_dtt(xc,False), # DCT-IV
                self.fold_dtt(xc,True))  # DST-IV

    def test_imclt0(self, mx, flat = 0.0):
        """
        Perform inverse MCLT transform, using modified sine window
        @param cs - frequency domain data [[IDCT-IV],[IDST-IV]]
        @param flat - extend window zeros on the ends (by this), flat 1.0 in the center (by twice that).
               Valid Princen-Bradley condition
        @return array of pixel domain lapped data, twice dct size
        """
        n2 = len(mx)
        n = n2 >> 1
        xc = mx[:]
#        xc = self.unfold_dtt(cs[0], False)
#        xs = self.unfold_dtt(cs[1], True)
        w = self.mclt_window_sin_mod(n, 0, flat) # may use cached data
        for i in range(n2):
            xc[i] = mx[i] * w[i] # (xc[i]+xs[i])
        return xc
        
    def test_imclt(self, cs, flat = 0.0):
        """
        Perform inverse MCLT transform, using modified sine window
        @param cs - frequency domain data [[IDCT-IV],[IDST-IV]]
        @param flat - extend window zeros on the ends (by this), flat 1.0 in the center (by twice that).
               Valid Princen-Bradley condition
        @return array of pixel domain lapped data, twice dct size
        """
        n = len(cs[0])
        n2 = n << 1
        xc = self.unfold_dtt(cs[0], False)
        xs = self.unfold_dtt(cs[1], True)
        w = self.mclt_window_sin_mod(n, 0, flat) # may use cached data
        for i in range(n2):
            xc[i] =  0.5* w[i]*(xc[i]+xs[i])
#            xc[i] = 0.5* w[i]*(xc[i])
        return xc
        

