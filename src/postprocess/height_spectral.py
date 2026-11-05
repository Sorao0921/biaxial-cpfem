"""FFT band indicators for surface height distributions."""

import numpy as np


def fft_bands(field,dx,dy,grain_diameter):
    """Phase-preserving FFT bands on a symmetric reflected periodic extension.

    All spectra use the SAME geometry-derived wavelengths. A plane is removed
    for spectral analysis only; reflection avoids a height jump at the seam.
    """
    z=np.asarray(field,float);ny,nx=z.shape
    if not np.isfinite(z).all() or min(dx,dy,grain_diameter)<=0:raise ValueError('Invalid FFT geometry')
    xx,yy=np.meshgrid((np.arange(nx)-(nx-1)/2)*dx,(np.arange(ny)-(ny-1)/2)*dy)
    design=np.column_stack([np.ones(z.size),xx.ravel(),yy.ravel()])
    trend=(design@np.linalg.lstsq(design,z.ravel(),rcond=None)[0]).reshape(z.shape)
    residual=z-trend
    extended=np.pad(residual,((0,ny),(0,nx)),mode='symmetric')
    spectrum=np.fft.fft2(extended,norm='ortho')
    fx=np.fft.fftfreq(2*nx,d=dx);fy=np.fft.fftfreq(2*ny,d=dy)
    radial=np.hypot(fy[:,None],fx[None,:]);non_dc=radial>0
    low=non_dc&(radial<1/(4*grain_diameter))
    mid=(radial>=1/(4*grain_diameter))&(radial<1/grain_diameter)
    high=radial>=1/grain_diameter
    result={};energy={}
    for name,mask in [('low',low),('grain_scale',mid),('high',high)]:
        result[name]=np.fft.ifft2(spectrum*mask,norm='ortho').real[:ny,:nx]
        energy[name]=float(np.sum(abs(spectrum[mask])**2)/4)
    return {'fields':result,'energy':energy,'detrended':residual,'trend':trend}


