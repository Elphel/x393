#!/usr/bin/env python
# encoding: utf-8
from __future__ import division
from __future__ import print_function
from ast import parse

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
import matplotlib.pyplot as plt
import dtt_rad2
#import sys
def test1():
#    x=[1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
#    x=[0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
    x=[1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0]
    dtt = dtt_rad2.DttRad2()
    print("CN1=",dtt.CN1)
    print("SN1=",dtt.SN1)
    print ("x=",x)
#    y = dtt.dct_ii(x)
#    print ("dctii(x)=",y)

    y = dtt.dct_iv(x)
    print ("dctiv(x)=",y)
    z = dtt.dct_iv(y)
    print ("dctiv(dctiv(x))=",z)


    y = dtt.dst_iv(x)
    print ("dstiv(x)=",y)
    z = dtt.dst_iv(y)
    print ("dstiv(dstiv(x))=",z)

#    x = create_test1(l = 1.0, k = 4, p = 5, n = 8)
    x = create_test1(l = 100.0, k = 4, p = 7, n = 8)
#    pars = setup_test1()
#    pars = setup_test2()
    pars = setup_test2()
#    plt.plot(x)
    plt.plot(x,"bo")
    y = test_clt_iclt(plt,dtt, x, pars, flat=0.0)
    plt.plot(y,"g")
    plt.ylabel('values')
    plt.show()
    



def create_test1(l = 1.0, k = 4, p = 5, n=8):
    x = [0]*n*(k+1)
    for i in range (len(x)):
        x[i] = l;
        j = i % p
        if j == 0:
            x[i] += 1
        elif j == 1:
            x[i] += 2
        elif j == 2:
            x[i] += 3
    return x

def setup_test1():
    return [{"poffs":-1, "woffs": 1.0, "roffs":-1.0},
            {"poffs":-1, "woffs": 1.0, "roffs":-1.0},
            {"poffs": 1, "woffs":-1.0, "roffs": 1.0},
            {"poffs": 1, "woffs":-1.0, "roffs": 1.0}]
def setup_test2():
    return [{"poffs": 0, "woffs": .5, "roffs":-.5},
            {"poffs": 0, "woffs": .5, "roffs":-.5},
            {"poffs": 1, "woffs":-.5, "roffs": .5},
            {"poffs": 1, "woffs":-.5, "roffs": .5}]

def setup_test20():
    return [{"poffs": 0, "woffs": .0, "roffs":-.5},
            {"poffs": 0, "woffs": .0, "roffs":-.5},
            {"poffs": 1, "woffs": .0, "roffs": .5},
            {"poffs": 1, "woffs": .0, "roffs": .5}]


def test_clt_iclt(plt, dtt, x, pars,flat=0 ):
    y = [0.0]*len(x)
    t = len(pars)
    n = len(x)//(t+1)
    n2 =n * 2
    cmodes=("r--","b--","v--",'y--')
    for it in range(t):
        x_start = n * it +pars[it]["poffs"]
        mx = [0]*n2
        dbg_x=[]
        for i in range(n2):
            j = x_start + i
            if j < 0: j = 0
            if j >= len(x): j = len(x) - 1
            mx[i] = x[j]
            dbg_x.append(j)
        print("it=",it)    
        print("dbg_x=",dbg_x)    
        print("mx=",mx)    
#        plt.plot(dbg_x,mx, "r")    
#            plt.plot(y,"g--")  

        cs= dtt.mclt_norot(mx, offset=pars[it]["woffs"], flat = flat)
##        cs= dtt.test_mclt(plt, dbg_x, cmodes[it], mx, offset=pars[it]["woffs"], flat = flat)
        
        if pars[it]["roffs"] != 0.0:
            cs = dtt.clt_rot(cs,pars[it]["roffs"])

        mix= dtt.imclt(cs, flat = flat)
##        mix= dtt.test_imclt(cs, flat = flat)
        for i in range (n2):
            y[n * it + i] += mix[i]
    return y        
test1()
            