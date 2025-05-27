
import { useState } from 'react';
import { Button } from "@/components/ui/button";
import { Fingerprint } from "lucide-react";

interface FingerprintScannerProps {
  onAuthenticated: () => void;
  isDisabled?: boolean;
}

const FingerprintScanner = ({ onAuthenticated, isDisabled = false }: FingerprintScannerProps) => {
  const [isScanning, setIsScanning] = useState(false);
  const [scanComplete, setScanComplete] = useState(false);

  const handleScan = () => {
    if (isDisabled) return;
    
    setIsScanning(true);
    setScanComplete(false);
    
    // Simulate scanning process
    setTimeout(() => {
      setIsScanning(false);
      setScanComplete(true);
      
      // Call authentication callback after brief delay
      setTimeout(() => {
        onAuthenticated();
        setScanComplete(false);
      }, 500);
    }, 2000);
  };

  return (
    <div className="flex flex-col items-center space-y-6">
      <div className="relative">
        {/* Scanner Animation Container */}
        <div 
          className={`
            relative w-32 h-32 rounded-full border-4 cursor-pointer
            transition-all duration-300 flex items-center justify-center
            ${isDisabled 
              ? 'border-gray-300 bg-gray-100 cursor-not-allowed' 
              : isScanning 
                ? 'border-blue-500 bg-blue-50 animate-pulse' 
                : scanComplete
                  ? 'border-green-500 bg-green-50'
                  : 'border-blue-400 bg-blue-50 hover:border-blue-500 hover:bg-blue-100'
            }
          `}
          onClick={handleScan}
        >
          <Fingerprint 
            className={`
              w-16 h-16 transition-all duration-300
              ${isDisabled 
                ? 'text-gray-400' 
                : isScanning 
                  ? 'text-blue-600' 
                  : scanComplete
                    ? 'text-green-600'
                    : 'text-blue-500'
              }
            `} 
          />
          
          {/* Scanning Animation Rings */}
          {isScanning && (
            <>
              <div className="absolute inset-0 rounded-full border-2 border-blue-400 animate-ping" />
              <div className="absolute inset-2 rounded-full border-2 border-blue-300 animate-ping animation-delay-200" />
              <div className="absolute inset-4 rounded-full border-2 border-blue-200 animate-ping animation-delay-400" />
            </>
          )}
          
          {/* Success Ring */}
          {scanComplete && (
            <div className="absolute inset-0 rounded-full border-4 border-green-500 animate-pulse" />
          )}
        </div>
        
        {/* Scanner Line Animation */}
        {isScanning && (
          <div className="absolute inset-0 overflow-hidden rounded-full">
            <div className="w-full h-0.5 bg-blue-500 absolute top-1/2 left-0 transform -translate-y-1/2 animate-pulse" />
            <div className="w-full h-0.5 bg-blue-400 absolute top-1/2 left-0 transform -translate-y-1/2 animate-bounce" />
          </div>
        )}
      </div>
      
      <div className="text-center space-y-2">
        {isDisabled ? (
          <p className="text-gray-500 font-medium">Already checked out for today</p>
        ) : isScanning ? (
          <div className="space-y-2">
            <p className="text-blue-600 font-medium">Scanning fingerprint...</p>
            <div className="flex justify-center space-x-1">
              <div className="w-2 h-2 bg-blue-500 rounded-full animate-bounce" />
              <div className="w-2 h-2 bg-blue-500 rounded-full animate-bounce animation-delay-100" />
              <div className="w-2 h-2 bg-blue-500 rounded-full animate-bounce animation-delay-200" />
            </div>
          </div>
        ) : scanComplete ? (
          <p className="text-green-600 font-medium">Authentication successful!</p>
        ) : (
          <>
            <p className="text-gray-700 font-medium">Touch to scan</p>
            <p className="text-sm text-gray-500">Place your finger on the scanner</p>
          </>
        )}
      </div>
      
      {!isDisabled && !isScanning && !scanComplete && (
        <Button 
          onClick={handleScan}
          className="w-full max-w-xs"
          variant="outline"
        >
          <Fingerprint className="w-4 h-4 mr-2" />
          Start Scan
        </Button>
      )}
    </div>
  );
};

export default FingerprintScanner;
