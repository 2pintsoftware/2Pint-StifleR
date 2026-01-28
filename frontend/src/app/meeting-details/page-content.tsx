'use client';

import React, { useRef, useState, useEffect } from 'react';
import AudioPlayer, { AudioPlayerHandle } from '@/components/AudioPlayer';
import TranscriptView, { TranscriptSegment } from '@/components/TranscriptView';
import { invoke } from '@tauri-apps/api/core';

interface Meeting {
  id: string;
  title: string;
  folder_path: string;
  transcript_segments: TranscriptSegment[];
}

interface MeetingDetailsPageContentProps {
  meeting: Meeting;
}

const MeetingDetailsPageContent: React.FC<MeetingDetailsPageContentProps> = ({
  meeting,
}) => {
  const audioPlayerRef = useRef<AudioPlayerHandle>(null);
  const [audioFilePath, setAudioFilePath] = useState<string | null>(null);
  const [currentPlaybackTime, setCurrentPlaybackTime] = useState(0);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const loadAudioPath = async () => {
      try {
        setIsLoading(true);
        setError(null);
        
        const path = await invoke<string | null>('get_meeting_audio_path', {
          meetingFolder: meeting.folder_path,
        });
        
        setAudioFilePath(path);
      } catch (err) {
        console.error('Failed to load audio path:', err);
        setError('Failed to load audio file');
      } finally {
        setIsLoading(false);
      }
    };

    loadAudioPath();
  }, [meeting.folder_path]);

  const handleSegmentClick = (audioStartTime: number) => {
    audioPlayerRef.current?.seekTo(audioStartTime);
  };

  const handleTimeUpdate = (time: number) => {
    setCurrentPlaybackTime(time);
  };

  return (
    <div className="max-w-4xl mx-auto p-6">
      <header className="mb-6">
        <h1 className="text-2xl font-bold text-gray-900">{meeting.title}</h1>
      </header>

      <div className="space-y-6">
        <section className="bg-white rounded-lg shadow-md p-6">
          <h2 className="text-lg font-semibold text-gray-800 mb-4">Transcript</h2>
          
          <TranscriptView
            segments={meeting.transcript_segments}
            onSegmentClick={handleSegmentClick}
            currentPlaybackTime={currentPlaybackTime}
          />
        </section>

        {isLoading && (
          <div className="text-center text-gray-500 py-4">
            Loading audio...
          </div>
        )}

        {error && (
          <div className="text-center text-red-500 py-4">
            {error}
          </div>
        )}

        {!isLoading && audioFilePath && (
          <div className="sticky bottom-0 bg-gray-100 p-4 rounded-lg shadow-lg">
            <AudioPlayer
              ref={audioPlayerRef}
              audioFilePath={audioFilePath}
              onTimeUpdate={handleTimeUpdate}
            />
          </div>
        )}

        {!isLoading && !audioFilePath && !error && (
          <div className="text-center text-gray-500 py-4">
            No audio recording available for this meeting.
          </div>
        )}
      </div>
    </div>
  );
};

export default MeetingDetailsPageContent;
