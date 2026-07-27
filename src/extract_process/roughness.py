import numpy as np
import pandas as pd


class SurfaceRoughnessAnalyzer:
    """
    Class to calculate the arithmetic mean deviation Sa of the absolute value of z-direction residuals from the least squares plane obtained from x, y, z coordinate DataFrame.

    Least squares plane:
        z = ax + by + c

    z-direction residual:
        residual = z - z_plane

    Surface roughness:
        Sa = mean(abs(residual))
        Sq = sqrt(mean(residual^2))
        Sz = max(residual) - min(residual)
    """

    def __init__(self):
        pass

    def get_xyz(self, df: pd.DataFrame) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
        """
        Extract x, y, z coordinates from DataFrame.

        Parameters
        ----------
        df : pd.DataFrame
            Column 0: node_id
            Column 1: x
            Column 2: y
            Column 3: z
        """
        if df.shape[1] < 4:
            raise ValueError("DataFrame must have at least 4 columns: x, y, z.")

        x = df.iloc[:, 1].to_numpy()
        y = df.iloc[:, 2].to_numpy()
        z = df.iloc[:, 3].to_numpy()

        return x, y, z

    def fit_plane(self, df: pd.DataFrame) -> tuple[float, float, float]:
        """
        Find the least squares plane z = ax + by + c.
        """
        x, y, z = self.get_xyz(df)

        A = np.column_stack([x, y, np.ones_like(x)])

        coeffs, *_ = np.linalg.lstsq(A, z, rcond=None)

        a, b, c = coeffs
        return a, b, c

    def calc_z_residuals(
        self,
        df: pd.DataFrame,
        a: float,
        b: float,
        c: float,
    ) -> np.ndarray:
        """
        Calculate z-direction residuals against the least squares plane.
        """
        x, y, z = self.get_xyz(df)

        z_plane = a * x + b * y + c
        residuals = z - z_plane

        return residuals

    def calc_sa_from_residuals(self, residuals: np.ndarray) -> float:
        """
        Calculate the mean of the absolute values of z-direction residuals.
        """
        return float(np.mean(np.abs(residuals)))

    def calc_sq_from_residuals(self, residuals: np.ndarray) -> float:
        """
        Calculate the root mean square of z-direction residuals.
        """
        return float(np.sqrt(np.mean(residuals**2)))

    def calc_sz_from_residuals(self, residuals: np.ndarray) -> float:
        """
        Calculate the maximum height of the surface, defined as the difference between the maximum and minimum z-direction residuals.
        """
        return float(np.max(residuals) - np.min(residuals))

    def analyze_df(self, df: pd.DataFrame) -> dict:
        """
        Calculate the least squares plane, residuals, and Sa for the DataFrame all at once.
        """
        a, b, c = self.fit_plane(df)
        residuals = self.calc_z_residuals(df, a, b, c)
        sa = self.calc_sa_from_residuals(residuals)
        sq = self.calc_sq_from_residuals(residuals)
        sz = self.calc_sz_from_residuals(residuals)
        result = {
            "a": a,
            "b": b,
            "c": c,
            "residuals": residuals,
            "sa": sa,
            "sq": sq,
            "sz": sz,
            "num_nodes": len(df) + 1,
        }

        return result

    def analyze_csv(self, csv_path) -> dict:
        """
        Read CSV and calculate least squares plane, residuals, and Sa.
        """
        df = pd.read_csv(csv_path, header=None)
        return self.analyze_df(df)
