import numpy as np
import pytest
from src.postprocess.height_spectral import fft_bands


def test_fft_band_reconstruction_conserves_detrended_signal_and_energy():
    ny=40;nx=48;dx=.01;dy=.012
    x,y=np.meshgrid(np.arange(nx)*dx,np.arange(ny)*dy)
    field=.03*x+.02*y+np.cos(2*np.pi*x/.24)+.2*np.cos(2*np.pi*y/.048)
    result=fft_bands(field,dx,dy,.06)
    reconstructed=sum(result['fields'].values())
    np.testing.assert_allclose(reconstructed,result['detrended'],atol=1.e-12)
    assert sum(result['energy'].values())==pytest.approx(np.sum(result['detrended']**2),rel=1.e-12)
    assert result['energy']['low']>0 and result['energy']['high']>0

