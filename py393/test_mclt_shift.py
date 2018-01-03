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
import numpy
import matplotlib.pyplot as plt
from matplotlib.ticker import AutoMinorLocator
import dtt_rad2
#import sys
def test1():
    save_dir="/home/eyesis/Documents/wiki_blogs/bayer-mclt/"

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
    x = create_test1(l = 10.0, a= 1.0, k = 4, p = 6, n = 8)
#    pars = setup_test1()
#    pars = setup_test2()
    pars = setup_test10()
    y = test_clt_iclt(plt,dtt, x, pars, flat=1.0, path = save_dir+"test_flat1_10.png")

    pars = setup_test1()
    y = test_clt_iclt(plt,dtt, x, pars, flat=1.0, path = save_dir+"test_flat1_1.png")

    pars = setup_test1i0()
    y = test_clt_iclt(plt,dtt, x, pars, flat=1.0, path = save_dir+"test_flat1_1i0.png")

    pars = setup_test1i()
    y = test_clt_iclt(plt,dtt, x, pars, flat=1.0, path = save_dir+"test_flat1_1i.png")

#    plt.plot(y,"g")
#    plt.ylabel('values')
#    plt.grid()
#    plt.show()
    

def create_test1(l = 1.0, a=1.0, k = 4, p = 5, n=8):
    x = [0]*n*(k+1)
    for i in range (len(x)):
        x[i] = l;
        j = i % p
        if j == 0:
            x[i] += 1*a
        elif j == 1:
            x[i] += 2*a
        elif j == 2:
            x[i] += 3*a
    return x

def create_test2(l = 1.0, a=1.0, k = 4, p = 5, n=8):
    x = [0]*n*(k+1)
    for i in range (len(x)):
        x[i] = l;
        j = i % p
        if j == 0: #approx Gaussian
            x[i] += .24 * a
        elif j == 1:
            x[i] += .70 * a
        elif j == 2:
            x[i] += 1.0 * a
        elif j == 3:
            x[i] += .70 * a
        elif j == 4:
            x[i] += .24 * a
    return x



def setup_test1():
    return [{"poffs":-1, "woffs": 1.0, "roffs":-1.0},
            {"poffs":-1, "woffs": 1.0, "roffs":-1.0},
            {"poffs": 1, "woffs":-1.0, "roffs": 1.0},
            {"poffs": 1, "woffs":-1.0, "roffs": 1.0}]
def setup_test10():
    return [{"poffs":-1, "woffs": 0.0, "roffs":-1.0},
            {"poffs":-1, "woffs": 0.0, "roffs":-1.0},
            {"poffs": 1, "woffs": 0.0, "roffs": 1.0},
            {"poffs": 1, "woffs": 0.0, "roffs": 1.0}]
def setup_test1i():
    return [{"poffs": 1, "woffs":-1.0, "roffs": 1.0},
            {"poffs": 1, "woffs":-1.0, "roffs": 1.0},
            {"poffs":-1, "woffs": 1.0, "roffs":-1.0},
            {"poffs":-1, "woffs": 1.0, "roffs":-1.0}]
def setup_test1i0():
    return [{"poffs": 1, "woffs": 0.0, "roffs": 1.0},
            {"poffs": 1, "woffs": 0.0, "roffs": 1.0},
            {"poffs":-1, "woffs": 0.0, "roffs":-1.0},
            {"poffs":-1, "woffs": 0.0, "roffs":-1.0}]


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

def setup_test3():
    return [{"poffs": 1, "woffs":-.5, "roffs": .5},
            {"poffs": 1, "woffs":-.5, "roffs": .5},
            {"poffs": 0, "woffs": .5, "roffs":-.5},
            {"poffs": 0, "woffs": .5, "roffs":-.5}]

def setup_test30():
    return [{"poffs": 1, "woffs": .0, "roffs": .5},
            {"poffs": 1, "woffs": .0, "roffs": .5},
            {"poffs": 0, "woffs": .0, "roffs":-.5},
            {"poffs": 0, "woffs": .0, "roffs":-.5}]

def test_clt_iclt(plt, dtt, x, pars,flat=0, wnd_scale = 5.0, path=""):
#    save_dir="/home/eyesis/Documents/wiki_blogs/bayer-mclt/"
    fig, (ax1,ax2) = plt.subplots(2,1) #,sharex=True)
    print ("fig.get_size_inches() =",fig.get_size_inches()) # 8.6
    fig.set_size_inches(16,12)
    print ("fig.get_size_inches() =",fig.get_size_inches()) # 8.6
##    plt.xlabel('sample number')
##    plt.ylabel('source values')
    ax1.plot(x,"k",label="source data")
    ax2.plot(x,"k:",label="source data")
    
    y = [0.0]*len(x)
    t = len(pars)
    n = len(x)//(t+1)
    n2 =n * 2
    cmodes1=     ("r--","r--","b--",'b--')
    labels1=     ("window*data 1,2","","window*data 3,4","")
    cmodes1_wnd= ("r:", "r:", "b:", 'b:')
    labels1_wnd= ("window 1,2","","window 3,4","")
    cmodes1_bar= ("r-|", "r-|", "b-|", 'b-|')
    labels1_bar= ("span 1,2","","span 3,4","")
    cmodes2=     ("r-", "r-", "b-", 'b-')
    labels2 =    ("shifted 1,2","","shifted 3,4","")
    cmodes3=     ("r-", "r-", "b-", 'b-')
    labels3 =    ("double-windowed 1,2","","double-windowed 3,4","")
    cmodes2_bar= ("r-|", "r-|", "b-|", 'b-|')
    labels2_bar= ("span 1,2","","span 3,4","")
    for it in range(t):
        x_start = n * it +pars[it]["poffs"]
        mx = [0]*n2
        dbg_x=[]
        dbg_xi=[]

        for i in range(n2):
            j = x_start + i
            if j < 0: j = 0
            if j >= len(x): j = len(x) - 1
            mx[i] = x[j]
            dbg_x.append(j)
            dbg_xi.append(n * it + i)
        cs= dtt.mclt_norot_dbg( ax1,
                                dbg_x,
                                cmodes1[it],
                                labels1[it],
                                mx,
                                offset =    pars[it]["woffs"],
                                flat =      flat,
                                cmode_wnd = cmodes1_wnd[it],
                                label_wnd = labels1_wnd[it],
                                wnd_scale = wnd_scale)
        
        if pars[it]["roffs"] != 0.0:
            cs = dtt.clt_rot(cs,pars[it]["roffs"])

        mix= dtt.imclt_dbg(ax1, dbg_x, cmodes2[it], cs, flat = flat)
        
        if cmodes3[it]:
            if labels3[it]:
                ax2.plot(dbg_xi, mix, cmodes3[it],label=labels3[it])
            else:        
                ax2.plot(dbg_xi, mix, cmodes3[it])    

        
        for i in range (n2):
            y[n * it + i] += mix[i]
# show intrerval bars
        if (cmodes1_bar[it]):
            if labels1_bar[it]:
                ax1.plot([dbg_x[0],dbg_x[-1]], [-0.5*(it+2)]*2, cmodes1_bar[it],label=labels1_bar[it])
            else:
                ax1.plot([dbg_x[0],dbg_x[-1]], [-0.5*(it+2)]*2, cmodes1_bar[it])
        if (cmodes2_bar[it]):
            if labels2_bar[it]:
                ax2.plot([dbg_xi[0],dbg_xi[-1]], [-0.5*(it+2)]*2, cmodes2_bar[it],label=labels2_bar[it])
            else:
                ax2.plot([dbg_xi[0],dbg_xi[-1]], [-0.5*(it+2)]*2, cmodes2_bar[it])
# For autoscale            
    if (cmodes1_bar[0]):
        ax1.plot([0], [-0.5*(t+2)], "r")
    if (cmodes2_bar[0]):
        ax2.plot([0], [-0.5*(t+2)], "r")
            
    ax2.plot(y,"g",label="restored data")

    ax1.minorticks_on() # no effect
    ax2.minorticks_on()

    ax1.grid(which='major', linestyle='-', linewidth='0.5', color='grey')
    ax1.grid(which='minor', axis="x", linestyle=':', linewidth='0.5', color='black')
    ax2.grid(which='major', linestyle='-', linewidth='0.5', color='grey')
    ax2.grid(which='minor', axis="x", linestyle=':', linewidth='0.5', color='black')
    
    ax1.set_xticks(numpy.arange(0, 40, 8))
    ax2.set_xticks(numpy.arange(0, 40, 8))

    minorLocator = AutoMinorLocator(8)
    ax1.xaxis.set_minor_locator(minorLocator)
    ax2.xaxis.set_minor_locator(minorLocator)
    
    ax1.set_title("Source data")
    ax1.set_xlabel('sample number')
    ax1.set_ylabel('source value')
    ax1.legend() #['a','b','c'])
    ax2.set_title("Restrored data")
    ax2.set_xlabel('sample number')
    ax2.set_ylabel('restored value')
    ax2.legend()
#    plt.show()

#    F = pylab.gcf()            
#    DefaultSize = F.get_size_inches()
#    plt.savefig("/home/eyesis/Documents/wiki_blogs/bayer-mclt/test02.png",dpi=(100))
    if path:
        plt.savefig(path,dpi=(50))
    else:
        plt.show()
                
    return y        
test1()
            